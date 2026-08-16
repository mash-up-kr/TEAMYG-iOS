//
//  ToppingAddStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import Foundation
import Observation
import UIComponent

@Observable @MainActor
public final class ToppingAddStore: MVIStore {
    public private(set) var state: State
    private let dependencies: Dependencies
    private var cameraSetupTask: Task<Void, Never>?
    private var cameraSwitchTask: Task<Void, Never>?
    private var photoCaptureTask: Task<Void, Never>?

    init(
        state: State,
        dependencies: Dependencies
    ) {
        self.state = state
        self.dependencies = dependencies
    }

    /// Composition Root(App) 가 조립할 때 쓰는 진입점. `State` 는 모듈 내부 타입으로 남긴다.
    public convenience init(
        entryPoint: PhotoSelectionEntryPoint,
        canvasDate: CanvasStore.CalendarDate,
        dependencies: Dependencies
    ) {
        self.init(
            state: State(entryPoint: entryPoint, canvasDate: canvasDate),
            dependencies: dependencies
        )
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .screenDisappeared,
             .sceneBecameActive, .sceneBecameInactive:
            handleLifecycleIntent(intent)
        case .flashTapped, .cameraPositionTapped, .shutterTapped:
            handleCameraControlIntent(intent)
        case .flowCloseTapped, .retakeTapped, .photoConfirmed, .cameraRetryTapped,
             .analysisReturnedToPhotoSelection, .settingsTapped, .toastDismissed:
            handleNavigationIntent(intent)
        }
    }

    private func handleLifecycleIntent(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            guard state.screen.needsRunningCamera else { return }
            prepareCamera()
        case .screenDisappeared, .sceneBecameInactive:
            suspendCamera()
        case .sceneBecameActive:
            guard state.screen.needsRunningCamera else { return }
            prepareCamera()
        default:
            break
        }
    }

    private func handleCameraControlIntent(_ intent: Intent) {
        switch intent {
        case .flashTapped:
            state.flashMode = state.flashMode.toggled
        case .cameraPositionTapped:
            switchCamera()
        case .shutterTapped:
            capturePhoto()
        default:
            break
        }
    }

    private func handleNavigationIntent(_ intent: Intent) {
        switch intent {
        case .flowCloseTapped:
            closeFlow()
        case .retakeTapped:
            state.capturedPhotoData = nil
            state.screen = .camera
            prepareCamera()
        case .photoConfirmed:
            guard state.capturedPhotoData != nil else { return }
            state.screen = .analysisLoading
        case .cameraRetryTapped:
            prepareCamera()
        case .analysisReturnedToPhotoSelection:
            state.screen = state.entryPoint.confirmationScreen
        case .settingsTapped:
            Task { [dependencies] in
                await dependencies.openSettings()
            }
        case .toastDismissed:
            state.showsToast = false
        default:
            break
        }
    }

    private func switchCamera() {
        guard !state.isSwitchingCamera, !state.isCapturing else { return }
        state.isSwitchingCamera = true
        cameraSwitchTask = Task { [weak self, dependencies] in
            let switchedPosition = await dependencies.switchCamera()
            guard let self else { return }

            state.isSwitchingCamera = false
            guard !Task.isCancelled, let switchedPosition else { return }

            state.cameraPosition = switchedPosition
            if switchedPosition == .front {
                state.flashMode = .off
            }
        }
    }

    private func closeFlow() {
        cancelCameraTasks()
        Task { [dependencies] in
            await dependencies.stopCamera()
            await dependencies.onFlowClosed()
        }
    }

    private func prepareCamera() {
        cameraSetupTask?.cancel()
        state.cameraPhase = .preparing

        cameraSetupTask = Task { [weak self, dependencies] in
            let currentAuthorization = await dependencies.authorizationStatus()
            let isAuthorized: Bool

            switch currentAuthorization {
            case .authorized:
                isAuthorized = true
            case .notDetermined:
                isAuthorized = await dependencies.requestAuthorization()
            case .denied, .restricted:
                isAuthorized = false
            }

            guard !Task.isCancelled, let self else { return }
            guard isAuthorized else {
                state.cameraPhase = .permissionDenied
                state.screen = .cameraPermissionError
                return
            }

            let didStart = await dependencies.startCamera()
            guard !Task.isCancelled else { return }

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
    }

    private func capturePhoto() {
        guard state.isShutterEnabled else { return }

        state.isCapturing = true
        photoCaptureTask = Task { [weak self, dependencies, flashMode = state.flashMode] in
            let photoData = await dependencies.capturePhoto(flashMode)
            guard let self else { return }

            state.isCapturing = false
            guard !Task.isCancelled, let photoData else { return }

            state.capturedPhotoData = photoData
            state.screen = .cameraConfirmation
            await dependencies.stopCamera()
        }
    }

    private func suspendCamera() {
        cancelCameraTasks()
        state.cameraPhase = .idle
        Task { [dependencies] in
            await dependencies.stopCamera()
        }
    }

    private func cancelCameraTasks() {
        cameraSetupTask?.cancel()
        cameraSwitchTask?.cancel()
        photoCaptureTask?.cancel()
        cameraSetupTask = nil
        cameraSwitchTask = nil
        photoCaptureTask = nil
        state.isSwitchingCamera = false
        state.isCapturing = false
    }

    var previewSource: (any CameraPreviewSource)? {
        dependencies.previewSource
    }
}

extension ToppingAddStore {
    public struct State: Equatable, Sendable {
        let entryPoint: PhotoSelectionEntryPoint
        let canvasDate: CanvasStore.CalendarDate
        var screen: Screen
        var cameraPhase: CameraPhase
        var flashMode: CameraFlashMode
        var cameraPosition: CameraPosition
        var capturedPhotoData: Data?
        var showsToast: Bool
        var isSwitchingCamera: Bool
        var isCapturing: Bool

        init(
            entryPoint: PhotoSelectionEntryPoint,
            canvasDate: CanvasStore.CalendarDate = .today,
            screen: Screen? = nil,
            cameraPhase: CameraPhase = .idle,
            flashMode: CameraFlashMode = .off,
            cameraPosition: CameraPosition = .back,
            capturedPhotoData: Data? = nil,
            showsToast: Bool = true,
            isSwitchingCamera: Bool = false,
            isCapturing: Bool = false
        ) {
            self.entryPoint = entryPoint
            self.canvasDate = canvasDate
            self.screen = screen ?? entryPoint.initialScreen
            self.cameraPhase = cameraPhase
            self.flashMode = flashMode
            self.cameraPosition = cameraPosition
            self.capturedPhotoData = capturedPhotoData
            self.showsToast = showsToast
            self.isSwitchingCamera = isSwitchingCamera
            self.isCapturing = isCapturing
        }

        var isShutterEnabled: Bool {
            cameraPhase == .running && !isSwitchingCamera && !isCapturing
        }

        var isFlashControlEnabled: Bool {
            cameraPosition == .back
        }

        var canvasDateText: String {
            "\(canvasDate.monthName) \(canvasDate.day)"
        }

        var canvasWeekdayText: String {
            "(\(canvasDate.weekdayName))"
        }
    }

    public enum Intent {
        case screenAppeared
        case screenDisappeared
        case flowCloseTapped
        case toastDismissed
        case flashTapped
        case cameraPositionTapped
        case shutterTapped
        case retakeTapped
        case photoConfirmed
        case cameraRetryTapped
        case analysisReturnedToPhotoSelection
        case settingsTapped
        case sceneBecameActive
        case sceneBecameInactive
    }

    public enum PhotoSelectionEntryPoint: Equatable, Sendable {
        case camera
        case gallery

        var initialScreen: Screen {
            switch self {
            case .camera: .camera
            case .gallery: .gallery
            }
        }

        var confirmationScreen: Screen {
            switch self {
            case .camera: .cameraConfirmation
            case .gallery: .galleryConfirmation
            }
        }
    }

    enum Screen: Equatable, Sendable {
        case camera
        case cameraConfirmation
        case cameraPermissionError
        case cameraUnavailable
        case gallery
        case galleryConfirmation
        case analysisLoading

        var isCameraError: Bool {
            self == .cameraPermissionError || self == .cameraUnavailable
        }

        var needsRunningCamera: Bool {
            self == .camera || isCameraError
        }
    }

    enum CameraPhase: Equatable, Sendable {
        case idle
        case preparing
        case running
        case permissionDenied
        case unavailable
    }

    public struct Dependencies: Sendable {
        let previewSource: (any CameraPreviewSource)?
        let authorizationStatus: @Sendable () async -> CameraAuthorization
        let requestAuthorization: @Sendable () async -> Bool
        let startCamera: @Sendable () async -> Bool
        let stopCamera: @Sendable () async -> Void
        let switchCamera: @Sendable () async -> CameraPosition?
        let capturePhoto: @Sendable (CameraFlashMode) async -> Data?
        let openSettings: @MainActor @Sendable () async -> Void
        let onFlowClosed: @MainActor @Sendable () async -> Void
    }
}
