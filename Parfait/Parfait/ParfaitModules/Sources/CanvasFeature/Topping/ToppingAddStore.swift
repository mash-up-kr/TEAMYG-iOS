//
//  ToppingAddStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

// swiftlint:disable file_length

import CanvasDomain
import CoreGraphics
import Foundation
import Observation
import UIKit
import UIComponent

@Observable @MainActor
final class ToppingAddStore: MVIStore {
    private(set) var state: State

    /// 토스트처럼 한 번만 소비해야 하는 결과는 화면 상태와 분리한다 (`docs/mvi.md`).
    @ObservationIgnored private let eventChannel = EventChannel<Event>()

    @ObservationIgnored private lazy var camera = CameraFlow { [weak self] event in
        self?.handleCameraEvent(event)
    }
    private let dependencies: Dependencies
    @ObservationIgnored private lazy var objectExtractor: any ObjectExtracting = ObjectExtractor()
    @ObservationIgnored private lazy var borderRenderer = ToppingBorderRenderer()
    @ObservationIgnored private lazy var maskRenderer = ToppingMaskRenderer()
    /// 브러시 스트로크를 얹기 전의 Vision 원본 마스크. 스트로크는 매번 여기서부터 다시 재생한다.
    private var baseMask: CGImage?
    private var analysisTask: Task<Void, Never>?
    private var extractorResetTask: Task<Void, Never>?
    private var borderRenderTask: Task<Void, Never>?
    private var maskRenderTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    init(
        canvasDate: CalendarDate,
        photoSource: PhotoSource,
        canvasContent: CanvasStore.CanvasContent? = nil,
        dependencies: Dependencies
    ) {
        state = State(canvasDate: canvasDate, photoSource: photoSource, canvasContent: canvasContent)
        self.dependencies = dependencies
    }

    /// 화면이 사라졌다 다시 나타나도 이어 받을 수 있도록 구독마다 새 스트림을 내준다.
    func eventStream() -> AsyncStream<Event> {
        eventChannel.stream()
    }

    func send(_ intent: Intent) {
        switch intent {
        case .settingsTapped:
            openSystemSettings()

        case .toastDismissed:
            state.showsToast = false

        case .screenAppeared, .screenDisappeared, .sceneBecameActive, .sceneEnteredBackground,
             .cameraRetryTapped, .flashTapped, .cameraPositionTapped, .shutterTapped, .retakeTapped:
            handleCameraIntent(intent)

        case .photoConfirmed, .galleryPhotoConfirmed, .recentUploadConfirmed, .analysisCancelled, .candidateTapped,
             .candidateSelectionBackTapped, .analysisErrorClosed, .cutoutResultClosed,
             .photoEditTapped, .cutoutConfirmed:
            handleAnalysisIntent(intent)

        case .borderWidthChanged, .borderWidthEditingChanged, .borderColorSelected,
             .borderUndoTapped, .borderRedoTapped, .borderEditClosed, .borderAreaTabTapped,
             .borderConfirmed:
            handleBorderIntent(intent)

        case .brushModeSelected, .brushDiameterChanged, .brushStrokeEnded, .maskUndoTapped,
             .maskRedoTapped, .manualCutoutClosed, .manualCutoutConfirmed:
            handleManualCutoutIntent(intent)

        case .placementCanvasResized, .placementMoved, .placementScaled, .placementRotated,
             .placementClosed, .placementConfirmed:
            handlePlacementIntent(intent)
        }
    }

    private func handleAnalysisIntent(_ intent: Intent) {
        switch intent {
        case .photoConfirmed:
            proceedWithCapturedPhoto()
        case .galleryPhotoConfirmed(let assetIdentifier):
            confirmGalleryPhoto(assetIdentifier: assetIdentifier)
        case .recentUploadConfirmed(let upload):
            openRecentUpload(upload)
        case .analysisCancelled:
            cancelAnalysis()
        case .candidateTapped(let normalizedPoint):
            extractCandidate(at: normalizedPoint)
        case .candidateSelectionBackTapped, .analysisErrorClosed:
            returnToPhotoConfirm()
        default:
            handleCutoutResultIntent(intent)
        }
    }

    private func handleBorderIntent(_ intent: Intent) {
        switch intent {
        case .borderEditClosed:
            switch state.cutoutPath {
            case .manual:
                state.screen = .manualCutout
            case .recentUpload:
                // 최근 업로드 경로는 갤러리로 돌아가며 다른 사진을 고를 수 있으므로 초안을 버린다.
                releaseExtractedTopping()
                state.screen = .gallery
            case .automatic:
                state.screen = .candidateSelection
            }
        case .borderAreaTabTapped:
            guard state.extractedTopping != nil, state.cutoutPath != .recentUpload else { break }
            state.cutoutPath = .manual
            state.screen = .manualCutout
        case .borderConfirmed:
            guard let extractedTopping = state.extractedTopping else { break }
            state.placementEditor.prepare(toppingPixelSize: extractedTopping.pixelSize)
            state.screen = .placement
        default:
            if state.borderEditor.apply(intent) {
                renderBorderSilhouette()
            }
        }
    }

    private func handleManualCutoutIntent(_ intent: Intent) {
        switch intent {
        case .manualCutoutClosed:
            state.screen = .candidateSelection
        case .manualCutoutConfirmed:
            state.screen = .borderEdit
            tightenCutout()
        default:
            if state.maskEditor.apply(intent) {
                renderMask()
            }
        }
    }

    private func releaseExtractedTopping() {
        borderRenderTask?.cancel()
        maskRenderTask?.cancel()
        baseMask = nil
        state.extractedTopping = nil
        state.borderSilhouette = nil
        state.maskEditor.reset()
        state.placementEditor.reset()
        state.cutoutPath = .automatic
    }

    private func resetToppingDraft() {
        releaseExtractedTopping()
        state.borderEditor = ToppingBorderEditor()
        Task { [borderRenderer] in await borderRenderer.reset() }
    }

    private func proceedWithCapturedPhoto() {
        switch camera.state.capturePhase {
        case .processing:
            // 아직 사진이 안 나왔다 — 나오는 대로 분석으로 넘긴다.
            camera.requestHandoffWhenCaptured()
            state.screen = .analysisLoading
        case .ready(_, let photoData):
            startAnalysis(of: .cameraPhoto(photoData, viewFinderRegion: camera.state.capturedViewFinderRegion))
        case .idle:
            break
        }
    }

    private func confirmGalleryPhoto(assetIdentifier: String) {
        state.galleryAssetIdentifier = assetIdentifier
        startAnalysis(of: .galleryAsset(identifier: assetIdentifier))
    }

    private func startAnalysis(of source: PhotoAnalysisSource) {
        analysisTask?.cancel()
        state.analysis = nil
        resetToppingDraft()
        state.screen = .analysisLoading

        analysisTask = Task { [weak self, objectExtractor, extractorResetTask] in
            do {
                await extractorResetTask?.value
                try Task.checkCancellation()
                let analysis = try await objectExtractor.analyze(source)
                guard let self, !Task.isCancelled else { return }
                state.analysis = analysis
                state.screen = .candidateSelection
                camera.releaseFreezeFrame()
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                state.screen = .analysisError
            }
        }
    }

    private func extractCandidate(at normalizedPoint: CGPoint) {
        guard state.screen == .candidateSelection,
              let candidate = state.analysis?.candidate(at: normalizedPoint)
        else { return }

        // 같은 후보를 다시 고르면 수동 마스크 초안이 살아 있어야 한다 (`topping_ui.md` §6.4).
        guard state.extractedTopping?.candidateID != candidate.id else {
            state.screen = .cutoutResult
            return
        }

        analysisTask?.cancel()
        releaseExtractedTopping()
        state.screen = .analysisLoading

        analysisTask = Task { [weak self, objectExtractor] in
            do {
                let topping = try await objectExtractor.extractTopping(candidateID: candidate.id)
                guard let self, !Task.isCancelled else { return }
                baseMask = topping.mask
                state.extractedTopping = topping
                state.screen = .cutoutResult
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                state.screen = .analysisError
            }
        }
    }

    /// 최근 업로드 누끼는 이미 잘라낸 결과물이라 분석·후보 선택을 건너뛰고 곧장 테두리 편집으로 간다
    /// (`canvas-policy.md` §5.3). 원본 사진이 없으므로 영역 편집은 이 경로에서 제공하지 않는다.
    private func openRecentUpload(_ upload: StoredImage) {
        analysisTask?.cancel()
        state.analysis = nil
        resetToppingDraft()

        guard let image = ToppingImageEncoder.decode(upload.imageData) else {
            state.screen = .analysisError
            return
        }
        state.extractedTopping = ExtractedTopping(
            candidateID: Self.recentUploadCandidateID,
            image: image,
            photo: image,
            mask: image
        )
        state.cutoutPath = .recentUpload
        state.screen = .borderEdit
        renderBorderSilhouette()
    }

    /// 최근 업로드에는 후보 번호가 없다. 실루엣 캐시 키로만 쓰이며 `resetToppingDraft` 가 매번 캐시를 비운다.
    private static let recentUploadCandidateID = -1

    private func returnToPhotoConfirm() {
        cancelAnalysis()
        state.screen = state.photoSource.confirmScreen
    }

    private func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        state.analysis = nil
        resetToppingDraft()
        extractorResetTask = Task { [objectExtractor] in
            await objectExtractor.reset()
        }
    }
}

extension ToppingAddStore {
    struct Dependencies: Sendable {
        let groupID: Int
        /// 오늘 캔버스 조회에 실패했으면 nil — 저장할 대상이 없다.
        let parfaitID: Int?
        let toppingUseCase: any ToppingUseCase
        let recentUploadsRepository: any RecentUploadsRepository
        /// 저장이 끝나 캔버스로 돌아가야 할 때 호출한다.
        let onSaved: @MainActor () -> Void

        init(
            groupID: Int,
            parfaitID: Int?,
            toppingUseCase: any ToppingUseCase,
            recentUploadsRepository: any RecentUploadsRepository,
            onSaved: @escaping @MainActor () -> Void
        ) {
            self.groupID = groupID
            self.parfaitID = parfaitID
            self.toppingUseCase = toppingUseCase
            self.recentUploadsRepository = recentUploadsRepository
            self.onSaved = onSaved
        }
    }

    var previewSource: any CameraPreviewSource {
        camera.previewSource
    }

    /// 카메라 상태는 `CameraFlow` 가 소유한다 — 뷰가 읽는 값만 그대로 넘겨준다.
    var cameraState: CameraFlowState {
        camera.state
    }
}

/// C-103 누끼 결과 화면(`cutoutResult`)에서 갈라지는 세 갈래 — 후보 다시 고르기·테두리·수동 편집.
private extension ToppingAddStore {
    func handleCutoutResultIntent(_ intent: Intent) {
        switch intent {
        case .cutoutResultClosed:
            // 초안(누끼·마스크·테두리)은 유지한 채 후보 선택으로만 돌아간다
            // (`canvas-policy.md` §5.4 "자동 누끼 초안을 유지한다").
            state.screen = .candidateSelection
        case .cutoutConfirmed:
            guard state.extractedTopping != nil else { break }
            state.screen = .borderEdit
            renderBorderSilhouette()
        case .photoEditTapped:
            guard state.extractedTopping != nil else { break }
            state.cutoutPath = .manual
            state.screen = .manualCutout
        default:
            break
        }
    }
}

/// 마스크·테두리 실루엣 다시 그리기. 셋 다 무거워 액터에 맡기고 결과만 상태에 얹는다.
private extension ToppingAddStore {
    func renderMask() {
        maskRenderTask?.cancel()
        guard let topping = state.extractedTopping, let baseMask else { return }

        let strokes = state.maskEditor.strokes
        maskRenderTask = Task { [weak self, maskRenderer, borderRenderer] in
            let cutout = await maskRenderer.cutout(
                photo: topping.photo,
                baseMask: baseMask,
                strokes: strokes
            )
            guard !Task.isCancelled, let self, let cutout else { return }

            state.extractedTopping = topping.replacingCutout(image: cutout.image, mask: cutout.mask)
            // 실루엣 캐시는 후보 ID 로만 구분한다 — 마스크가 바뀌면 통째로 버려야 한다.
            await borderRenderer.reset()
        }
    }

    /// C-104 를 빠져나갈 때 편집된 마스크에 맞춰 추출 캔버스를 다시 잘라낸다.
    /// 진행 중인 마스크 렌더는 버리고 스트로크 목록에서 최종 결과를 한 번에 만든다.
    func tightenCutout() {
        maskRenderTask?.cancel()
        guard state.maskEditor.hasEdits,
              let topping = state.extractedTopping,
              let editedBaseMask = baseMask
        else {
            renderBorderSilhouette()
            return
        }

        let strokes = state.maskEditor.strokes
        maskRenderTask = Task { [weak self, maskRenderer, borderRenderer] in
            let tightened = await maskRenderer.tightenedCutout(
                photo: topping.photo,
                baseMask: editedBaseMask,
                strokes: strokes
            )
            guard !Task.isCancelled, let self else { return }

            if let tightened {
                baseMask = tightened.baseMask
                state.maskEditor.translateStrokes(by: tightened.strokeOffset)
                state.extractedTopping = topping.replacingCanvas(
                    image: tightened.image,
                    photo: tightened.photo,
                    mask: tightened.mask
                )
                // 실루엣 캐시는 후보 ID 로만 구분한다 — 캔버스가 바뀌면 통째로 버려야 한다.
                await borderRenderer.reset()
            }
            renderBorderSilhouette()
        }
    }

    func renderBorderSilhouette() {
        borderRenderTask?.cancel()
        guard let topping = state.extractedTopping, state.borderEditor.border.isVisible else {
            state.borderSilhouette = nil
            return
        }
        let width = state.borderEditor.border.width
        borderRenderTask = Task { [weak self, borderRenderer] in
            let image = await borderRenderer.silhouette(of: topping, width: width)
            guard !Task.isCancelled, let image else { return }
            self?.state.borderSilhouette = BorderSilhouette(image: image)
        }
    }
}

/// 카메라 흐름은 `CameraFlow` 가 소유한다 (C-101 은 배경 편집과 공용 화면 — `canvas-policy.md` §5.1).
/// 여기서는 이 흐름의 화면 전이만 해석한다.
private extension ToppingAddStore {
    func handleCameraIntent(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .sceneBecameActive, .screenDisappeared, .sceneEnteredBackground:
            handleCameraLifecycleIntent(intent)
        case .cameraRetryTapped:
            camera.prepare()
        case .flashTapped:
            camera.toggleFlash()
        case .cameraPositionTapped:
            camera.switchCamera()
        case .shutterTapped(let viewFinderRegion):
            camera.capturePhoto(viewFinderRegion: viewFinderRegion)
        case .retakeTapped:
            guard camera.retake() else { break }
            state.screen = .camera
        default:
            break
        }
    }

    func handleCameraLifecycleIntent(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .sceneBecameActive:
            guard state.screen.needsRunningCamera else { return }
            camera.prepare()
        case .screenDisappeared:
            cancelAnalysis()
            camera.suspend()
        case .sceneEnteredBackground:
            camera.suspend()
        default:
            break
        }
    }

    func handleCameraEvent(_ event: CameraFlowEvent) {
        switch event {
        case .permissionDenied:
            state.screen = .cameraPermissionError
        case .unavailable:
            state.screen = .cameraUnavailable
        case .running:
            if state.screen.isCameraError { state.screen = .camera }
        case .freezeFrameReady:
            state.screen = .cameraConfirmation
        case .captureFinished(let photoData, let viewFinderRegion, let wantsHandoff):
            if wantsHandoff {
                startAnalysis(of: .cameraPhoto(photoData, viewFinderRegion: viewFinderRegion))
            } else {
                state.screen = .cameraConfirmation
            }
        case .captureFailed, .captureAborted:
            state.screen = .camera
        }
    }
}

private extension ToppingAddStore {
    func openSystemSettings() {
        Task {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            await UIApplication.shared.open(settingsURL)
        }
    }
}

/// C-106 배치와 저장 파이프라인. 확정 시 누끼를 PNG 로 굽고 업로드·배치까지 맡긴다.
private extension ToppingAddStore {
    func handlePlacementIntent(_ intent: Intent) {
        switch intent {
        case .placementClosed:
            guard state.saveState != .saving else { break }
            state.screen = .borderEdit
        case .placementConfirmed:
            saveTopping()
        default:
            state.placementEditor.apply(intent)
        }
    }

    /// 누끼를 PNG 로 굽고 업로드·배치까지 맡긴 뒤, 성공하면 최근 업로드에 남기고 캔버스로 돌아간다.
    func saveTopping() {
        // 이미 저장 중이면 조용히 무시한다 — 진행 중인 저장을 실패로 보고하면 안 된다.
        guard state.saveState != .saving else { return }
        guard let topping = state.extractedTopping,
              let parfaitID = dependencies.parfaitID,
              let pngData = ToppingImageEncoder.encodePNG(topping.image)
        else {
            eventChannel.send(.saveFailed)
            return
        }

        let draft = ToppingDraft(
            image: .topping(pngData: pngData),
            placement: state.placementEditor.placementValues(zOrder: nextZOrder),
            border: state.borderEditor.border.style
        )
        state.saveState = .saving

        saveTask = Task { [weak self, dependencies] in
            do {
                _ = try await dependencies.toppingUseCase.place(
                    draft,
                    groupID: dependencies.groupID,
                    parfaitID: parfaitID
                )
                // 서버 배치는 이미 끝났다 — 최근 업로드 기록 실패로 저장 전체를 물리지 않는다.
                _ = try? await dependencies.recentUploadsRepository.save(pngData)
                guard !Task.isCancelled, let self else { return }
                state.saveState = .idle
                dependencies.onSaved()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                state.saveState = .idle
                eventChannel.send(.saveFailed)
            }
        }
    }

    /// 새 토핑은 항상 맨 위에 얹는다.
    var nextZOrder: Int {
        let highest = state.canvasContent?.images.map(\.positionZ).max() ?? 0
        return Int(highest.rounded()) + 1
    }
}
