//
//  BackgroundImagePickerStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CanvasDomain
import Foundation
import Observation
import UIKit
import UIComponent

@Observable @MainActor
final class BackgroundImagePickerStore: MVIStore {
    private(set) var state: State

    /// 토스트처럼 한 번만 소비해야 하는 결과는 화면 상태와 분리한다 (`docs/mvi.md`).
    @ObservationIgnored private let eventChannel = EventChannel<Event>()

    @ObservationIgnored private lazy var camera = CameraFlow { [weak self] event in
        self?.handleCameraEvent(event)
    }
    private let dependencies: Dependencies
    @ObservationIgnored private var imagePreparationTask: Task<Void, Never>?

    init(state: State, dependencies: Dependencies) {
        self.state = state
        self.dependencies = dependencies
    }

    /// 화면이 사라졌다 다시 나타나도 이어 받을 수 있도록 구독마다 새 스트림을 내준다.
    func eventStream() -> AsyncStream<Event> {
        eventChannel.stream()
    }

    var previewSource: any CameraPreviewSource {
        camera.previewSource
    }

    /// 카메라 상태는 `CameraFlow` 가 소유한다 — 뷰가 읽는 값만 그대로 넘겨준다.
    var cameraState: CameraFlowState {
        camera.state
    }

    func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .screenDisappeared, .sceneBecameActive, .sceneEnteredBackground,
             .cameraGuideDismissed, .flashTapped, .cameraPositionTapped, .shutterTapped,
             .retakeTapped, .cameraRetryTapped:
            handleCameraIntent(intent)
        case .photoConfirmed, .galleryPhotoConfirmed, .recentUploadConfirmed:
            handleImageSelectionIntent(intent)
        case .settingsTapped:
            openSystemSettings()
        }
    }

    private func handleImageSelectionIntent(_ intent: Intent) {
        switch intent {
        case .photoConfirmed:
            prepareCapturedPhoto()
        case .galleryPhotoConfirmed(let assetIdentifier):
            prepareGalleryPhoto(assetIdentifier: assetIdentifier)
        case .recentUploadConfirmed(let upload):
            prepareRecentUpload(upload)
        default:
            break
        }
    }

    private func prepareCapturedPhoto() {
        switch camera.state.capturePhase {
        case .processing:
            // 아직 사진이 안 나왔다 — 나오는 대로 배경 준비로 넘긴다.
            camera.requestHandoffWhenCaptured()
            state.isPreparingImage = true
        case .ready(_, let photoData):
            prepareCameraPhoto(photoData, viewFinderRegion: camera.state.capturedViewFinderRegion)
        case .idle:
            break
        }
    }

    private func prepareCameraPhoto(_ photoData: Data, viewFinderRegion: ViewFinderRegion?) {
        prepareImage(source: .camera) {
            await BackgroundImageLoader.cameraJPEG(
                photoData: photoData,
                viewFinderRegion: viewFinderRegion
            )
        }
    }

    private func prepareGalleryPhoto(assetIdentifier: String) {
        prepareImage(source: .gallery) {
            await BackgroundImageLoader.galleryJPEG(assetIdentifier: assetIdentifier)
        }
    }

    private func prepareRecentUpload(_ upload: StoredImage) {
        prepareImage(source: .gallery) {
            await BackgroundImageLoader.recentUploadJPEG(upload.imageData)
        }
    }

    private func prepareImage(
        source: PhotoSource,
        operation: @escaping @MainActor @Sendable () async -> Data?
    ) {
        imagePreparationTask?.cancel()
        state.isPreparingImage = true
        imagePreparationTask = Task { [weak self, dependencies] in
            let jpegData = await operation()
            guard let self, !Task.isCancelled else { return }
            state.isPreparingImage = false
            guard let jpegData else {
                eventChannel.send(.imagePreparationFailed)
                return
            }
            dependencies.onImageSelected(jpegData, source)
        }
    }

    private func openSystemSettings() {
        Task {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            await UIApplication.shared.open(settingsURL)
        }
    }
}

/// 카메라 흐름은 `CameraFlow` 가 소유한다 (C-101 은 토핑 추가와 공용 화면 — `canvas-policy.md` §5.1).
/// 여기서는 배경 편집 흐름의 화면 전이만 해석한다.
private extension BackgroundImagePickerStore {
    func handleCameraIntent(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .sceneBecameActive, .screenDisappeared, .sceneEnteredBackground:
            handleCameraLifecycleIntent(intent)
        case .cameraGuideDismissed:
            state.showsCameraGuide = false
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
            cancelImagePreparation()
            state.screen = .camera
        default:
            break
        }
    }

    func handleCameraLifecycleIntent(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .sceneBecameActive:
            guard state.photoSource == .camera, state.screen.needsRunningCamera else { return }
            camera.prepare()
        case .screenDisappeared:
            cancelImagePreparation()
            camera.suspend()
        case .sceneEnteredBackground:
            camera.suspend()
        default:
            break
        }
    }

    func cancelImagePreparation() {
        imagePreparationTask?.cancel()
        imagePreparationTask = nil
        state.isPreparingImage = false
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
            state.screen = .cameraConfirmation
            guard wantsHandoff else { return }
            prepareCameraPhoto(photoData, viewFinderRegion: viewFinderRegion)
        case .captureFailed, .captureAborted:
            state.isPreparingImage = false
            state.screen = .camera
        }
    }
}
