//
//  CameraFlow.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

import Foundation

/// C-101 카메라의 상태 기계. 세션 켜기·끄기·전환·촬영을 소유한다.
///
/// C-101 은 토핑 추가와 캔버스 배경 편집이 **공용으로 쓰는 화면**이라(`canvas-policy.md` §5.1),
/// 두 Store(`ToppingAddStore`·`BackgroundImagePickerStore`)가 이 타입 하나를 각각 소유한다.
/// 화면 전이(`screen`)는 흐름마다 다르므로 여기서 다루지 않고 `Event` 로 올려 보낸다.
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

        captureTask = Task { [weak self, session, flashMode = state.flashMode] in
            async let pendingPhotoData = session.capturePhoto(flashMode: flashMode)
            let previewFrame = await session.latestPreviewFrame()

            guard let self, isLatestRequest(captureGeneration) else { return }
            if let previewFrame {
                state.capturePhase = .processing(previewFrame: previewFrame)
                handle(.freezeFrameReady)
            }

            let photoData = await pendingPhotoData
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
