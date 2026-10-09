//
//  ToppingAddStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

// swiftlint:disable file_length

import CanvasDomain
import Common
import CoreGraphics
import Foundation
import Observation
import UIKit
import UIComponent

@Observable @MainActor
// swiftlint:disable:next type_body_length
final class ToppingAddStore: MVIStore {
    private(set) var state: State

    /// 토스트처럼 한 번만 소비해야 하는 결과는 화면 상태와 분리한다 (`docs/mvi.md`).
    @ObservationIgnored private let eventChannel = EventChannel<Event>()

    @ObservationIgnored private lazy var camera = CameraFlow { [weak self] event in
        self?.handleCameraEvent(event)
    }
    private let dependencies: Dependencies
    private let makeAlbumPickerStore: AlbumPickerStoreFactory
    @ObservationIgnored private var albumPicker: (isLimited: Bool, store: AlbumPickerStore)?
    @ObservationIgnored private lazy var objectExtractor: any ObjectExtracting = ObjectExtractor()
    @ObservationIgnored private lazy var borderRenderer = ToppingBorderRenderer()
    @ObservationIgnored private lazy var maskRenderer = ToppingMaskRenderer()
    /// 브러시 스트로크를 얹기 전의 편집 캔버스 마스크. 스트로크는 매번 여기서부터 다시 재생한다.
    private var baseMask: CGImage?
    private var appliedStrokes: [ToppingBrushStroke] = []
    /// 대상 감지에 실패했을 때 빈 마스크의 C-104 를 만들며 되짚어 갈 마지막 분석 소스.
    private var lastAnalysisSource: PhotoAnalysisSource?
    private var analysisTask: Task<Void, Never>?
    private var extractorResetTask: Task<Void, Never>?
    private var borderRenderTask: Task<Void, Never>?
    private var maskRenderTask: Task<Void, Never>?
    private var cutoutApplyTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    @ObservationIgnored private let canvasRefreshTicker = CanvasRefreshTicker()
    private var canvasRefreshTask: Task<Void, Never>?

    init(
        canvasDate: CalendarDate,
        photoSource: PhotoSource,
        canvasContent: CanvasStore.CanvasContent? = nil,
        dependencies: Dependencies,
        makeAlbumPickerStore: @escaping AlbumPickerStoreFactory
    ) {
        state = State(canvasDate: canvasDate, photoSource: photoSource, canvasContent: canvasContent)
        self.dependencies = dependencies
        self.makeAlbumPickerStore = makeAlbumPickerStore
    }

    func albumPickerStore(isLimited: Bool) -> AlbumPickerStore {
        if let albumPicker, albumPicker.isLimited == isLimited {
            return albumPicker.store
        }
        let onPhotoConfirmed: (String) -> Void = { [weak self] assetIdentifier in
            self?.send(.galleryPhotoConfirmed(assetIdentifier: assetIdentifier))
        }
        let onRecentUploadConfirmed: (StoredImage) -> Void = { [weak self] upload in
            self?.send(.recentUploadConfirmed(upload))
        }
        let albumPickerStore = makeAlbumPickerStore(isLimited, true, onPhotoConfirmed, onRecentUploadConfirmed)
        albumPicker = (isLimited, albumPickerStore)
        return albumPickerStore
    }

    /// 화면이 사라졌다 다시 나타나도 이어 받을 수 있도록 구독마다 새 스트림을 내준다.
    func eventStream() -> AsyncStream<Event> {
        eventChannel.stream()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .sceneBecameActive:
            canvasRefreshTicker.start { [weak self] in
                self?.send(.canvasRefreshTicked)
            }
            guard state.screen.needsRunningCamera else { return }
            camera.prepare()
        case .screenDisappeared:
            stopCanvasRefresh()
            cancelAnalysis()
            camera.suspend()
        case .sceneEnteredBackground:
            stopCanvasRefresh()
            camera.suspend()
        case .canvasRefreshTicked:
            refreshCanvasContent()
        case .toastDismissed:
            state.showsToast = false
        case .flashTapped:
            camera.toggleFlash()
        case .cameraPositionTapped:
            camera.switchCamera()
        case .shutterTapped(let viewFinderRegion):
            camera.capturePhoto(viewFinderRegion: viewFinderRegion)
        case .retakeTapped:
            guard camera.retake() else { break }
            state.screen = .camera
        case .photoConfirmed:
            proceedWithCapturedPhoto()
        case .galleryPhotoConfirmed(let assetIdentifier):
            confirmGalleryPhoto(assetIdentifier: assetIdentifier)
        case .recentUploadConfirmed(let upload):
            openRecentUpload(upload)
        case .cameraRetryTapped:
            camera.prepare()
        case .settingsTapped:
            openSystemSettings()
        case .analysisCancelled:
            cancelAnalysis()
            eventChannel.send(.dismissRequested)
        case .candidateTapped(let normalizedPoint):
            extractCandidate(at: normalizedPoint)
        case .candidateSelectionBackTapped:
            returnToPhotoConfirm()
        case .brushModeSelected(let mode):
            state.maskEditor.selectBrushMode(mode)
        case .brushDiameterChanged(let diameter):
            state.maskEditor.changeBrushDiameter(diameter)
        case .brushStrokeEnded(let stroke):
            if state.maskEditor.record(stroke) {
                renderMask()
            }
        case .maskUndoTapped:
            if state.maskEditor.undo() {
                renderMask()
            }
        case .maskRedoTapped:
            if state.maskEditor.redo() {
                renderMask()
            }
        case .areaSelectionBackTapped:
            leaveAreaSelection()
        case .areaSelectionConfirmed:
            proceedToPlacement()
        case .borderWidthChanged(let width):
            state.border.width = width
            renderBorderSilhouette()
        case .borderColorSelected(let color):
            state.border.color = color
            renderBorderSilhouette()
        case .borderPanelExpandTapped:
            state.isBorderPanelExpanded = true
        case .borderPanelClosed:
            state.isBorderPanelExpanded = false
        case .placementCanvasResized(let canvasSize):
            updatePlacement { $0.resize(to: canvasSize) }
        case .placementTransformed(let transform):
            updatePlacement { $0.apply(transform) }
        case .placementBackTapped:
            leavePlacement()
        case .placementConfirmed:
            saveTopping()
        case .closeTapped:
            requestQuit()
        case .quitPopupVisibilityChanged(let quitConfirmation, let isPresented):
            if isPresented {
                state.quitConfirmation = quitConfirmation
            } else if state.quitConfirmation == quitConfirmation {
                state.quitConfirmation = nil
            }
        case .quitConfirmed:
            state.quitConfirmation = nil
            eventChannel.send(.dismissRequested)
        }
    }

    private func requestQuit() {
        guard state.saveState != .saving, state.extractionState == .idle else { return }
        switch state.screen {
        case .cameraConfirmation:
            state.quitConfirmation = .addPhoto
        case .gallery where albumPicker?.store.state.selectedPhoto != nil:
            state.quitConfirmation = .addPhoto
        case .candidateSelection, .areaSelection, .placement:
            state.quitConfirmation = .editPhoto
        default:
            eventChannel.send(.dismissRequested)
        }
    }

    private func leaveAreaSelection() {
        guard state.extractionState == .idle else { return }
        guard state.analysis != nil else {
            returnToPhotoSelection()
            return
        }
        state.screen = .candidateSelection
    }

    private func leavePlacement() {
        guard state.saveState != .saving else { return }
        guard !state.isRecentUpload else {
            returnToPhotoSelection()
            return
        }
        state.screen = .areaSelection
    }

    private func openPlacement() {
        guard let extractedTopping = state.extractedTopping else { return }
        state.placementEditor.prepare(toppingPixelSize: extractedTopping.pixelSize)
        state.isBorderPanelExpanded = true
        state.screen = .placement
        renderBorderSilhouette()
    }

    private func releaseExtractedTopping() {
        borderRenderTask?.cancel()
        maskRenderTask?.cancel()
        cutoutApplyTask?.cancel()
        baseMask = nil
        appliedStrokes = []
        // 추출 태스크를 취소하고 새 흐름을 시작하는 모든 경로가 여길 지난다 — 오버레이가 남지 않게 정리.
        state.extractionState = .idle
        state.extractedTopping = nil
        state.cutoutEditCanvas = nil
        state.cutoutHasArea = true
        state.borderSilhouette = nil
        state.border = ToppingBorder()
        state.maskEditor.reset()
        state.placementEditor.reset()
        state.isRecentUpload = false
    }

    private func resetToppingDraft() {
        releaseExtractedTopping()
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
        startAnalysis(of: .galleryAsset(identifier: assetIdentifier))
    }

    private func startAnalysis(of source: PhotoAnalysisSource) {
        lastAnalysisSource = source
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
                openAreaSelectionWithoutAnalysis()
            }
        }
    }

    /// 최근 업로드 누끼는 이미 잘라낸 결과물이라 분석·후보 선택·영역 편집을 건너뛰고 곧장 C-105 로 간다.
    /// 원본 사진이 없으므로 영역 편집은 이 경로에서 제공하지 않는다.
    private func openRecentUpload(_ upload: StoredImage) {
        lastAnalysisSource = nil
        analysisTask?.cancel()
        state.analysis = nil
        resetToppingDraft()

        guard let image = ToppingImageEncoder.decode(upload.imageData) else {
            eventChannel.send(.photoUnavailable)
            return
        }
        state.extractedTopping = ExtractedTopping(candidateID: Self.noCandidateID, image: image)
        state.isRecentUpload = true
        openPlacement()
    }

    /// 후보 번호가 없는 경로(최근 업로드·분석 없이 시작한 경로)의 자리표시자.
    /// 실루엣 캐시 키로만 쓰이며 `resetToppingDraft` 가 매번 캐시를 비운다.
    private static let noCandidateID = -1

    private func returnToPhotoConfirm() {
        cancelAnalysis()
        state.screen = state.photoSource.confirmScreen
    }

    private func returnToPhotoSelection() {
        cancelAnalysis()
        switch state.photoSource {
        case .camera:
            state.screen = .cameraConfirmation
        case .gallery:
            state.screen = .gallery
            albumPicker?.store.send(.selectionReset)
        }
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
        /// 배치 화면(C-105) 뒤에 깔리는 캔버스를 주기적으로 다시 받아오는 데 쓴다.
        let canvasUseCase: any CanvasUseCase
        let toppingUseCase: any ToppingUseCase
        let recentUploadsRepository: any RecentUploadsRepository
        /// 저장이 끝나 캔버스로 돌아가야 할 때 호출한다.
        let onSaved: @MainActor () -> Void

        init(
            groupID: Int,
            parfaitID: Int?,
            canvasUseCase: any CanvasUseCase,
            toppingUseCase: any ToppingUseCase,
            recentUploadsRepository: any RecentUploadsRepository,
            onSaved: @escaping @MainActor () -> Void
        ) {
            self.groupID = groupID
            self.parfaitID = parfaitID
            self.canvasUseCase = canvasUseCase
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

/// C-103 후보 선택 → 누끼 추출 → C-104.
private extension ToppingAddStore {
    func extractCandidate(at normalizedPoint: CGPoint) {
        // 추출 중 재진입 금지 — 화면이 안 바뀌므로 상태로 막는다.
        guard state.screen == .candidateSelection,
              state.extractionState == .idle,
              let candidate = state.analysis?.candidate(at: normalizedPoint)
        else { return }

        guard state.extractedTopping?.candidateID != candidate.id || state.cutoutEditCanvas == nil else {
            state.screen = .areaSelection
            return
        }

        analysisTask?.cancel()
        releaseExtractedTopping()
        // 추출은 이미 분석된 세션에서 마스크만 뽑는 짧은 작업 — 후보 화면 위 오버레이로 보여준다.
        state.extractionState = .extracting

        analysisTask = Task { [weak self, objectExtractor] in
            do {
                let topping = try await objectExtractor.extractTopping(candidateID: candidate.id)
                let canvas = try await objectExtractor.makeEditCanvas(candidateID: candidate.id)
                guard let self, !Task.isCancelled else { return }
                baseMask = canvas.mask
                state.extractedTopping = topping
                state.cutoutEditCanvas = canvas
                state.extractionState = .idle
                state.screen = .areaSelection
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                openAreaSelectionWithoutAnalysis()
            }
        }
    }

    func openAreaSelectionWithoutAnalysis() {
        guard let lastAnalysisSource else {
            failPhotoLoading()
            return
        }
        analysisTask?.cancel()
        resetToppingDraft()
        if state.screen != .analysisLoading {
            state.extractionState = .extracting
        }

        analysisTask = Task { [weak self, objectExtractor] in
            do {
                let canvas = try await objectExtractor.makeCutoutWithoutAnalysis(from: lastAnalysisSource)
                guard let self, !Task.isCancelled else { return }
                baseMask = canvas.mask
                state.cutoutEditCanvas = canvas
                state.extractedTopping = ExtractedTopping(candidateID: Self.noCandidateID, image: canvas.image)
                state.cutoutHasArea = false
                state.maskEditor.selectBrushMode(.fill)
                state.extractionState = .idle
                state.screen = .areaSelection
                camera.releaseFreezeFrame()
                eventChannel.send(.detectionFailed)
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                failPhotoLoading()
            }
        }
    }

    func failPhotoLoading() {
        returnToPhotoSelection()
        eventChannel.send(.photoUnavailable)
    }
}

/// 마스크·테두리 실루엣 다시 그리기. 셋 다 무거워 액터에 맡기고 결과만 상태에 얹는다.
private extension ToppingAddStore {
    func renderMask() {
        maskRenderTask?.cancel()
        guard let canvas = state.cutoutEditCanvas, let baseMask else { return }

        let strokes = state.maskEditor.strokes
        maskRenderTask = Task { [weak self, maskRenderer] in
            let cutout = await maskRenderer.cutout(
                photo: canvas.photo,
                baseMask: baseMask,
                strokes: strokes
            )
            guard !Task.isCancelled, let self, let cutout else { return }

            state.cutoutEditCanvas = canvas.replacingCutout(image: cutout.image, mask: cutout.mask)
            state.cutoutHasArea = cutout.hasArea
        }
    }

    func proceedToPlacement() {
        // 포함 영역이 하나도 없으면 다음 단계로 못 간다 — 빈 토핑이 C-105·저장까지 흘러가는 것을 막는다.
        guard state.cutoutHasArea, state.extractionState == .idle else { return }

        let strokes = state.maskEditor.strokes
        guard strokes != appliedStrokes,
              let topping = state.extractedTopping,
              let canvas = state.cutoutEditCanvas,
              let baseMask
        else {
            openPlacement()
            return
        }

        cutoutApplyTask?.cancel()
        state.extractionState = .extracting
        cutoutApplyTask = Task { [weak self, maskRenderer, borderRenderer] in
            let image = await maskRenderer.tightenedCutout(
                photo: canvas.photo,
                baseMask: baseMask,
                strokes: strokes
            )
            guard !Task.isCancelled, let self else { return }

            if let image {
                appliedStrokes = strokes
                state.extractedTopping = ExtractedTopping(candidateID: topping.candidateID, image: image)
                // 실루엣 캐시는 후보 ID 로만 구분한다 — 토핑이 바뀌면 통째로 버려야 한다.
                await borderRenderer.reset()
                guard !Task.isCancelled else { return }
            }
            state.extractionState = .idle
            openPlacement()
        }
    }

    func renderBorderSilhouette() {
        borderRenderTask?.cancel()
        guard let topping = state.extractedTopping, state.border.isVisible,
              state.borderRenderLongEdge > 0
        else {
            state.borderSilhouette = nil
            return
        }
        let width = state.border.width
        let renderedLongEdge = state.borderRenderLongEdge
        borderRenderTask = Task { [weak self, borderRenderer] in
            let image = try? await borderRenderer.silhouette(
                of: topping,
                width: width,
                renderedLongEdge: renderedLongEdge
            )
            guard !Task.isCancelled, let image else { return }
            self?.state.borderSilhouette = BorderSilhouette(image: image)
        }
    }
}

private extension ToppingAddStore {
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

/// C-105 배치와 저장 파이프라인. 확정 시 누끼를 PNG 로 굽고 업로드·배치까지 맡긴다.
private extension ToppingAddStore {
    func updatePlacement(_ update: (inout ToppingPlacementEditor) -> Void) {
        let longEdgeBeforeUpdate = state.borderRenderLongEdge
        update(&state.placementEditor)
        guard state.borderRenderLongEdge != longEdgeBeforeUpdate else { return }
        renderBorderSilhouette()
    }

    /// 누끼를 PNG 로 굽고 업로드·배치까지 맡긴 뒤, 성공하면 최근 업로드에 남기고 캔버스로 돌아간다.
    func saveTopping() {
        // 이미 저장 중이면 조용히 무시한다 — 진행 중인 저장을 실패로 보고하면 안 된다.
        guard state.saveState != .saving else { return }
        guard let topping = state.extractedTopping,
              let parfaitID = dependencies.parfaitID
        else {
            eventChannel.send(.saveFailed)
            return
        }

        let placementEditor = state.placementEditor
        let zOrder = nextZOrder
        let border = state.border.style
        state.saveState = .saving

        saveTask = Task { [weak self, dependencies] in
            guard let upload = await Self.encodedUpload(from: topping.image) else {
                guard let self else { return }
                state.saveState = .idle
                eventChannel.send(.saveFailed)
                return
            }
            let pngData = upload.pngData
            let draft = ToppingDraft(
                image: .topping(pngData: pngData),
                placement: placementEditor.placementValues(zOrder: zOrder, scaleFactor: upload.scaleFactor),
                border: border
            )

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

    @concurrent
    static func encodedUpload(from image: CGImage) async -> (pngData: Data, scaleFactor: Double)? {
        let cropped = image.croppedRemovingSymmetricMargin()
        guard let pngData = ToppingImageEncoder.encodePNG(cropped) else { return nil }

        let scaleFactor = Double(max(cropped.width, cropped.height))
            / Double(max(image.width, image.height))
        return (pngData, scaleFactor)
    }

    /// 새 토핑은 항상 맨 위에 얹는다.
    var nextZOrder: Int {
        let highest = state.canvasContent?.images.map(\.positionZ).max() ?? 0
        return Int(highest.rounded()) + 1
    }
}

/// 배치 화면(C-105) 뒤 캔버스를 10초마다 서버 값으로 맞춘다. 사용자의 배치 초안
/// (`placementEditor`)과는 분리된 배경이라 통째로 갈아 끼워도 안전하다.
private extension ToppingAddStore {
    func stopCanvasRefresh() {
        canvasRefreshTicker.stop()
        canvasRefreshTask?.cancel()
        canvasRefreshTask = nil
    }

    func refreshCanvasContent() {
        guard state.screen == .placement,
              let parfaitID = dependencies.parfaitID,
              canvasRefreshTask == nil
        else { return }

        canvasRefreshTask = Task { [weak self, dependencies] in
            let parfait = try? await dependencies.canvasUseCase.fetchToday(groupID: dependencies.groupID)
            guard !Task.isCancelled, let self else { return }
            canvasRefreshTask = nil
            guard let parfait else { return }
            // 새벽 3시 경계를 넘겨 오늘 캔버스가 바뀌었다면 남의 캔버스를 배경에 깔면 안 된다.
            guard parfait.id == parfaitID else {
                canvasRefreshTicker.stop()
                return
            }
            state.canvasContent = CanvasStore.CanvasContent(parfait)
        }
    }
}
