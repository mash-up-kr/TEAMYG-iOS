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

    private let cameraSession = CameraSession()
    private let dependencies: Dependencies
    @ObservationIgnored private var cameraSetupTask: Task<Void, Never>?
    @ObservationIgnored private var cameraSwitchTask: Task<Void, Never>?
    @ObservationIgnored private var photoCaptureTask: Task<Void, Never>?
    @ObservationIgnored private var imagePreparationTask: Task<Void, Never>?
    private var cameraGeneration = 0

    init(state: State, dependencies: Dependencies) {
        self.state = state
        self.dependencies = dependencies
    }

    /// 화면이 사라졌다 다시 나타나도 이어 받을 수 있도록 구독마다 새 스트림을 내준다.
    func eventStream() -> AsyncStream<Event> {
        eventChannel.stream()
    }

    var previewSource: any CameraPreviewSource {
        cameraSession.previewSource
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
        switch state.photoCapturePhase {
        case .processing:
            state.isPreparingImage = true
        case .ready(_, let photoData):
            prepareImage(source: .camera) {
                await BackgroundImageLoader.cameraJPEG(
                    photoData: photoData,
                    viewFinderRegion: self.state.capturedViewFinderRegion
                )
            }
        case .idle:
            break
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

/// 카메라 세션 켜기·끄기와 촬영. 토핑 추가와 같은 generation 규약으로 늦은 요청을 버린다.
private extension BackgroundImagePickerStore {
    func handleCameraIntent(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .sceneBecameActive:
            resumeCameraIfNeeded()
        case .screenDisappeared:
            imagePreparationTask?.cancel()
            imagePreparationTask = nil
            suspendCamera()
        case .sceneEnteredBackground:
            suspendCamera()
        case .cameraGuideDismissed:
            state.showsCameraGuide = false
        case .flashTapped:
            state.flashMode = state.flashMode.toggled
        case .cameraPositionTapped:
            switchCamera()
        case .shutterTapped(let viewFinderRegion):
            capturePhoto(viewFinderRegion: viewFinderRegion)
        case .retakeTapped:
            retakePhoto()
        case .cameraRetryTapped:
            prepareCamera()
        default:
            break
        }
    }

    func resumeCameraIfNeeded() {
        guard state.photoSource == .camera, state.screen.needsRunningCamera else { return }
        prepareCamera()
    }

    func prepareCamera() {
        cameraSetupTask?.cancel()
        let generation = nextCameraGeneration()
        state.cameraPhase = .preparing

        cameraSetupTask = Task { [weak self] in
            guard let self, await resolveAuthorization() else { return }
            await startCamera(generation: generation)
        }
    }

    func resolveAuthorization() async -> Bool {
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

    func startCamera(generation: Int) async {
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

    func suspendCamera() {
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

    func switchCamera() {
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

    func capturePhoto(viewFinderRegion: ViewFinderRegion?) {
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

            let shouldPrepareImage = state.isPreparingImage
            state.photoCapturePhase = .ready(previewFrame: previewFrame, photoData: photoData)
            photoCaptureTask = nil
            state.screen = .cameraConfirmation
            await cameraSession.stop(generation: nextCameraGeneration())

            if shouldPrepareImage {
                prepareCapturedPhoto()
            }
        }
    }

    func retakePhoto() {
        guard state.isRetakeEnabled else { return }
        photoCaptureTask?.cancel()
        photoCaptureTask = nil
        imagePreparationTask?.cancel()
        imagePreparationTask = nil
        state.isPreparingImage = false
        state.photoCapturePhase = .idle
        state.capturedViewFinderRegion = nil
        state.screen = .camera
        prepareCamera()
    }

    func nextCameraGeneration() -> Int {
        cameraGeneration += 1
        return cameraGeneration
    }

    func isLatestRequest(_ generation: Int) -> Bool {
        !Task.isCancelled && generation == cameraGeneration
    }

    func cancelCameraTasks() {
        cameraSetupTask?.cancel()
        cameraSwitchTask?.cancel()
        photoCaptureTask?.cancel()
        cameraSetupTask = nil
        cameraSwitchTask = nil
        photoCaptureTask = nil
        state.isSwitchingCamera = false
    }
}
