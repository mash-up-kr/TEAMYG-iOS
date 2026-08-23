//
//  ToppingAddStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import CoreGraphics
import Foundation
import Observation
import UIKit
import UIComponent

@Observable @MainActor
final class ToppingAddStore: MVIStore {
    private(set) var state: State

    private let cameraSession = CameraSession()
    private let objectExtractor: any ObjectExtracting
    private let borderRenderer = ToppingBorderRenderer()
    private let maskRenderer = ToppingMaskRenderer()
    /// 브러시 스트로크를 얹기 전의 Vision 원본 마스크. 스트로크는 매번 여기서부터 다시 재생한다.
    private var baseMask: CGImage?
    private var cameraSetupTask: Task<Void, Never>?
    private var cameraSwitchTask: Task<Void, Never>?
    private var photoCaptureTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var extractorResetTask: Task<Void, Never>?
    private var borderRenderTask: Task<Void, Never>?
    private var maskRenderTask: Task<Void, Never>?
    /// 켜기/끄기 요청에 붙이는 일련번호. 발급은 순서가 보장되는 MainActor 에서만 한다.
    private var cameraGeneration = 0

    init(
        canvasDate: CalendarDate,
        photoSource: PhotoSource,
        canvasContent: CanvasStore.CanvasContent? = nil,
        objectExtractor: any ObjectExtracting = ObjectExtractor()
    ) {
        state = State(canvasDate: canvasDate, photoSource: photoSource, canvasContent: canvasContent)
        self.objectExtractor = objectExtractor
    }

    var previewSource: any CameraPreviewSource {
        cameraSession.previewSource
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

        case .photoConfirmed, .galleryPhotoConfirmed, .analysisCancelled, .candidateTapped,
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
            guard state.cutoutPath == .automatic else {
                state.screen = .manualCutout
                break
            }
            releaseExtractedTopping()
            state.screen = .candidateSelection
        case .borderAreaTabTapped:
            guard state.extractedTopping != nil else { break }
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
            renderBorderSilhouette()
        default:
            if state.maskEditor.apply(intent) {
                renderMask()
            }
        }
    }

    private func renderMask() {
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

    /// 저장 파이프라인(`docs/worklog/topping/topping_cutout_progress.md` §2.2)이 붙기 전이라
    /// 배치 확정은 아직 화면 이탈만 하고 서버에 올리지 않는다.
    private func handlePlacementIntent(_ intent: Intent) {
        switch intent {
        case .placementClosed:
            state.screen = .borderEdit
        case .placementConfirmed:
            break
        default:
            state.placementEditor.apply(intent)
        }
    }

    private func renderBorderSilhouette() {
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
        switch state.photoCapturePhase {
        case .processing:
            state.screen = .analysisLoading
        case .ready(_, let photoData):
            startAnalysis(of: .cameraPhoto(photoData, viewFinderRegion: state.capturedViewFinderRegion))
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
                releaseCapturedPreviewFrame()
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

/// C-103 누끼 결과 화면(`cutoutResult`)에서 갈라지는 세 갈래 — 후보 다시 고르기·테두리·수동 편집.
private extension ToppingAddStore {
    private func handleCutoutResultIntent(_ intent: Intent) {
        switch intent {
        case .cutoutResultClosed:
            releaseExtractedTopping()
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

/// 카메라 세션 켜기·끄기와 촬영. `cameraGeneration` 으로 뒤늦게 도착한 옛 요청을 걸러낸다.
private extension ToppingAddStore {
    private func handleCameraIntent(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .sceneBecameActive:
            resumeCameraIfNeeded()
        case .screenDisappeared:
            cancelAnalysis()
            suspendCamera()
        case .sceneEnteredBackground:
            suspendCamera()
        case .cameraRetryTapped:
            prepareCamera()
        case .flashTapped:
            state.flashMode = state.flashMode.toggled
        case .cameraPositionTapped:
            switchCamera()
        case .shutterTapped(let viewFinderRegion):
            capturePhoto(viewFinderRegion: viewFinderRegion)
        case .retakeTapped:
            retakePhoto()
        default:
            break
        }
    }

    private func resumeCameraIfNeeded() {
        guard state.screen.needsRunningCamera else { return }
        prepareCamera()
    }

    private func prepareCamera() {
        cameraSetupTask?.cancel()
        let generation = nextCameraGeneration()
        state.cameraPhase = .preparing

        cameraSetupTask = Task { [weak self] in
            guard let self, await resolveAuthorization() else { return }
            await startCamera(generation: generation)
        }
    }

    private func resolveAuthorization() async -> Bool {
        let isAuthorized = switch CameraPermission.current() {
        case .authorized: true
        case .notDetermined: await CameraPermission.request()
        case .denied, .restricted: false
        }

        guard !Task.isCancelled else { return false }
        guard isAuthorized else {
            state.cameraPhase = .permissionDenied
            state.screen = .cameraPermissionError
            return false
        }
        return true
    }

    private func startCamera(generation: Int) async {
        let didStart = await cameraSession.start(generation: generation)
        guard isLatestRequest(generation) else { return }

        if didStart {
            state.cameraPhase = .running
            if state.screen.isCameraError {
                state.screen = .camera
            }
        } else {
            state.cameraPhase = .unavailable
            state.screen = .cameraUnavailable
        }
    }

    private func suspendCamera() {
        cancelCameraTasks()
        if case .processing = state.photoCapturePhase {
            state.photoCapturePhase = .idle
            state.capturedViewFinderRegion = nil
            state.screen = .camera
        }
        let generation = nextCameraGeneration()
        state.cameraPhase = .idle
        Task { [cameraSession] in
            await cameraSession.stop(generation: generation)
        }
    }

    private func switchCamera() {
        guard state.isCameraReady else { return }
        state.isSwitchingCamera = true
        cameraSwitchTask = Task { [weak self, cameraSession] in
            let switchedPosition = await cameraSession.switchCamera()
            guard let self else { return }

            state.isSwitchingCamera = false
            guard let switchedPosition else { return }

            state.cameraPosition = switchedPosition
            if switchedPosition == .front {
                state.flashMode = .off
            }
        }
    }

    private func capturePhoto(viewFinderRegion: ViewFinderRegion?) {
        guard state.isCameraReady else { return }

        let captureGeneration = nextCameraGeneration()
        state.capturedViewFinderRegion = viewFinderRegion
        state.photoCapturePhase = .processing(previewFrame: nil)

        photoCaptureTask = Task { [weak self, cameraSession, flashMode = state.flashMode] in
            async let pendingPhotoData = cameraSession.capturePhoto(flashMode: flashMode)
            let previewFrame = await cameraSession.latestPreviewFrame()

            guard let self, isLatestRequest(captureGeneration) else { return }
            if let previewFrame {
                state.photoCapturePhase = .processing(previewFrame: previewFrame)
                state.screen = .cameraConfirmation
            }

            let photoData = await pendingPhotoData
            guard isLatestRequest(captureGeneration) else { return }

            guard let photoData else {
                state.photoCapturePhase = .idle
                state.screen = .camera
                photoCaptureTask = nil
                prepareCamera()
                return
            }

            let shouldStartAnalysis = state.screen == .analysisLoading
            state.photoCapturePhase = .ready(previewFrame: previewFrame, photoData: photoData)
            photoCaptureTask = nil

            if shouldStartAnalysis {
                startAnalysis(of: .cameraPhoto(photoData, viewFinderRegion: viewFinderRegion))
            } else {
                state.screen = .cameraConfirmation
            }
            await cameraSession.stop(generation: nextCameraGeneration())
        }
    }
}

private extension ToppingAddStore {
    private func releaseCapturedPreviewFrame() {
        guard case .ready(let previewFrame, let photoData) = state.photoCapturePhase, previewFrame != nil else {
            return
        }
        state.photoCapturePhase = .ready(previewFrame: nil, photoData: photoData)
    }

    private func retakePhoto() {
        guard state.isRetakeEnabled else { return }
        photoCaptureTask?.cancel()
        photoCaptureTask = nil
        state.photoCapturePhase = .idle
        state.capturedViewFinderRegion = nil
        state.screen = .camera
        prepareCamera()
    }

    private func openSystemSettings() {
        Task {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            await UIApplication.shared.open(settingsURL)
        }
    }

    /// 켜기/끄기 요청에 붙일 새 일련번호. 뒤늦게 도착한 옛 요청은 `CameraSession` 이 무시한다.
    private func nextCameraGeneration() -> Int {
        cameraGeneration += 1
        return cameraGeneration
    }

    private func isLatestRequest(_ generation: Int) -> Bool {
        !Task.isCancelled && generation == cameraGeneration
    }

    private func cancelCameraTasks() {
        cameraSetupTask?.cancel()
        cameraSwitchTask?.cancel()
        photoCaptureTask?.cancel()
        cameraSetupTask = nil
        cameraSwitchTask = nil
        photoCaptureTask = nil
        state.isSwitchingCamera = false
    }
}
