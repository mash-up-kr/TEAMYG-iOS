//
//  CameraFlow.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

import Foundation

/// C-101 카메라의 상태 기계. 세션 켜기·끄기·전환·촬영을 소유한다.
///
/// 늦게 도착한 켜기/끄기 요청은 `generation` 으로 걸러낸다. 발급은 순서가 보장되는 MainActor 에서만 한다.
@Observable @MainActor
final class CameraFlow {
    private(set) var state = CameraFlowState()

    @ObservationIgnored private lazy var session = CameraSession()
    @ObservationIgnored private var setupTask: Task<Void, Never>?
    @ObservationIgnored private var switchTask: Task<Void, Never>?
    @ObservationIgnored private var captureTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    /// 줌 요청 번호. 켜기/끄기 `generation` 과 섞으면 줌이 대기 중인 켜기 요청을 무효로 만들어 따로 센다.
    @ObservationIgnored private var zoomRequest = 0
    @ObservationIgnored private let handle: @MainActor (CameraFlowEvent) -> Void

    init(onEvent handle: @escaping @MainActor (CameraFlowEvent) -> Void) {
        self.handle = handle
    }

    var previewSource: any CameraPreviewSource { session.previewSource }

    /// 촬영 결과가 준비되면 곧바로 다음 단계로 넘길지 여부. 촬영 중 `다음` 을 누른 경우다.
    func requestHandoffWhenCaptured() {
        state.wantsHandoff = true
    }

    func prepare() {
        setupTask?.cancel()
        let generation = nextGeneration()
        state.phase = .preparing

        setupTask = Task { [weak self] in
            guard let self, await resolveAuthorization() else { return }
            await start(generation: generation)
        }
    }

    func suspend() {
        cancelTasks()
        if case .processing = state.capturePhase {
            state.capturePhase = .idle
            state.capturedViewFinderRegion = nil
            state.wantsHandoff = false
            handle(.captureAborted)
        }
        guard state.phase != .idle else { return }

        let generation = nextGeneration()
        state.phase = .idle
        Task { [session] in
            await session.stop(generation: generation)
        }
    }

    func toggleFlash() {
        state.flashMode = state.flashMode.toggled
        Task { [session, flashMode = state.flashMode] in
            await session.setFlashMode(flashMode)
        }
    }

    /// 다음 단계 배율로 바꾼다. 장치가 못 내는 배율(초광각 없는 기기의 0.5배)은 세션이 잘라 적용하고,
    /// 버튼에는 실제 적용된 배율이 보인다 — 그런 기기에선 1배 ↔ 2배로만 돈다.
    /// 핀치로 맞춘 단계 밖 배율이면 소수점을 버린 배율로 간다 (1.4배 → 1배, 0.7배 → 최소 0.5배).
    func cycleZoom() {
        guard state.isReady else { return }
        let steps = CameraFlowState.zoomFactorSteps
        let nextZoomFactor = if let currentIndex = steps.firstIndex(of: state.zoomFactor) {
            steps[(currentIndex + 1) % steps.count]
        } else {
            max(state.zoomFactor.rounded(.down), CameraFlowState.zoomFactorRange.lowerBound)
        }
        applyZoom(nextZoomFactor)
    }

    /// 핀치 중 배율. 범위를 넘으면 잘라 적용한다.
    func pinchZoom(to zoomFactor: CGFloat) {
        guard state.isReady else { return }
        let range = CameraFlowState.zoomFactorRange
        applyZoom(min(max(zoomFactor, range.lowerBound), range.upperBound))
    }

    private func applyZoom(_ nextZoomFactor: CGFloat) {
        zoomRequest += 1
        // 연속 탭마다 Task 가 생기는데 actor 도착 순서는 보장되지 않는다 — 번호로 늦게 온 배율을 버린다.
        Task { [weak self, session, zoomRequest] in
            guard let appliedZoomFactor = await session.setZoomFactor(nextZoomFactor, request: zoomRequest) else {
                return
            }
            // 장치 값 ↔ 화면 배율 환산 오차(0.9999…)를 털어 단계 비교·소수점 버림 표기가 어긋나지 않게 한다.
            self?.state.zoomFactor = (appliedZoomFactor * 100).rounded() / 100
        }
    }

    func switchCamera() {
        guard state.isReady else { return }
        state.isSwitching = true
        switchTask = Task { [weak self, session] in
            let switchedPosition = await session.switchCamera()
            guard let self else { return }

            state.isSwitching = false
            guard let switchedPosition else { return }

            state.position = switchedPosition
            state.zoomFactor = 1
            if switchedPosition == .front {
                state.flashMode = .off
            }
        }
    }

    func capturePhoto(viewFinderRegion: ViewFinderRegion?) {
        guard state.isReady else { return }

        let captureGeneration = nextGeneration()
        state.capturedViewFinderRegion = viewFinderRegion
        state.capturePhase = .processing(previewFrame: nil)

        captureTask = Task { [weak self, session] in
            // 사진 출력으로 새로 찍지 않고 셔터 순간의 프레임을 그대로 쓴다 — 누른 뒤 움직여도 보던 장면이 저장된다.
            let frame = await session.currentFrame()
            guard let self, isLatestRequest(captureGeneration) else { return }

            let previewFrame = frame?.freezeFrame
            if let previewFrame {
                state.capturePhase = .processing(previewFrame: previewFrame)
                handle(.freezeFrameReady)
            }

            let photoData = await frame?.jpegData()
            guard isLatestRequest(captureGeneration) else { return }

            guard let photoData else {
                state.capturePhase = .idle
                state.wantsHandoff = false
                captureTask = nil
                handle(.captureFailed)
                prepare()
                return
            }

            let wantsHandoff = state.wantsHandoff
            state.wantsHandoff = false
            state.capturePhase = .ready(previewFrame: previewFrame, photoData: photoData)
            captureTask = nil
            handle(.captureFinished(photoData: photoData, viewFinderRegion: viewFinderRegion,
                                    wantsHandoff: wantsHandoff))
            await session.stop(generation: nextGeneration())
        }
    }

    /// 다시 찍기. 실제로 되돌렸으면 `true` — 호출부가 그때만 화면을 카메라로 되돌린다.
    @discardableResult
    func retake() -> Bool {
        guard state.isRetakeEnabled else { return false }
        captureTask?.cancel()
        captureTask = nil
        state.capturePhase = .idle
        state.capturedViewFinderRegion = nil
        state.wantsHandoff = false
        prepare()
        return true
    }

    /// 분석·배경 준비로 넘어간 뒤에는 프리즈 프레임을 들고 있을 이유가 없다 (수십 MB).
    func releaseFreezeFrame() {
        guard case .ready(let previewFrame, let photoData) = state.capturePhase, previewFrame != nil else {
            return
        }
        state.capturePhase = .ready(previewFrame: nil, photoData: photoData)
    }

    private func resolveAuthorization() async -> Bool {
        let isAuthorized = switch CameraPermission.current() {
        case .authorized: true
        case .notDetermined: await CameraPermission.request()
        case .denied, .restricted: false
        }

        guard !Task.isCancelled else { return false }
        guard isAuthorized else {
            state.phase = .permissionDenied
            handle(.permissionDenied)
            return false
        }
        return true
    }

    private func start(generation: Int) async {
        let didStart = await session.start(generation: generation)
        guard isLatestRequest(generation) else { return }

        if didStart {
            state.phase = .running
            handle(.running)
        } else {
            state.phase = .unavailable
            handle(.unavailable)
        }
    }

    private func nextGeneration() -> Int {
        generation += 1
        return generation
    }

    private func isLatestRequest(_ requestGeneration: Int) -> Bool {
        !Task.isCancelled && requestGeneration == generation
    }

    private func cancelTasks() {
        setupTask?.cancel()
        switchTask?.cancel()
        captureTask?.cancel()
        setupTask = nil
        switchTask = nil
        captureTask = nil
        state.isSwitching = false
    }
}
