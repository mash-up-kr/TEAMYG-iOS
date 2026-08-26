//
//  ToppingAddStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import CanvasDomain
import CoreGraphics
import Foundation
import Observation
import UIKit
import UIComponent

@Observable @MainActor
final class ToppingAddStore: MVIStore {
    private(set) var state: State

    private let cameraSession = CameraSession()
    private let dependencies: Dependencies
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
    private var saveTask: Task<Void, Never>?
    /// 켜기/끄기 요청에 붙이는 일련번호. 발급은 순서가 보장되는 MainActor 에서만 한다.
    private var cameraGeneration = 0

    init(
        canvasDate: CalendarDate,
        photoSource: PhotoSource,
        canvasContent: CanvasStore.CanvasContent? = nil,
        dependencies: Dependencies,
        objectExtractor: any ObjectExtracting = ObjectExtractor()
    ) {
        state = State(canvasDate: canvasDate, photoSource: photoSource, canvasContent: canvasContent)
        self.dependencies = dependencies
        self.objectExtractor = objectExtractor
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
             .placementClosed, .placementConfirmed, .saveErrorDismissed:
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
                releaseExtractedTopping()
                state.screen = .gallery
            case .automatic:
                releaseExtractedTopping()
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

/// C-103 누끼 결과 화면(`cutoutResult`)에서 갈라지는 세 갈래 — 후보 다시 고르기·테두리·수동 편집.
/// C-103 누끼 결과 화면(`cutoutResult`)에서 갈라지는 세 갈래 — 후보 다시 고르기·테두리·수동 편집.
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
        cameraSession.previewSource
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

/// C-106 배치와 저장 파이프라인. 확정 시 누끼를 PNG 로 굽고 업로드·배치까지 맡긴다.
private extension ToppingAddStore {
    private func handlePlacementIntent(_ intent: Intent) {
        switch intent {
        case .placementClosed:
            guard state.saveState != .saving else { break }
            state.screen = .borderEdit
        case .placementConfirmed:
            saveTopping()
        case .saveErrorDismissed:
            state.saveState = .idle
        default:
            state.placementEditor.apply(intent)
        }
    }

    /// 누끼를 PNG 로 굽고 업로드·배치까지 맡긴 뒤, 성공하면 최근 업로드에 남기고 캔버스로 돌아간다.
    private func saveTopping() {
        guard state.saveState != .saving,
              let topping = state.extractedTopping,
              let parfaitID = dependencies.parfaitID
        else {
            state.saveState = .failed
            return
        }
        guard let pngData = ToppingImageEncoder.encodePNG(topping.image) else {
            state.saveState = .failed
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
                state.saveState = .failed
            }
        }
    }

    /// 새 토핑은 항상 맨 위에 얹는다.
    private var nextZOrder: Int {
        let highest = state.canvasContent?.images.map(\.positionZ).max() ?? 0
        return Int(highest.rounded()) + 1
    }
}
