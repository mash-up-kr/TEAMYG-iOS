//
//  ToppingAddStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import Foundation
import Observation
import UIKit
import UIComponent

@Observable @MainActor
public final class ToppingAddStore: MVIStore {
    public private(set) var state: State

    private let cameraSession = CameraSession()
    private var cameraSetupTask: Task<Void, Never>?
    private var cameraSwitchTask: Task<Void, Never>?
    private var photoCaptureTask: Task<Void, Never>?
    /// 켜기/끄기 요청에 붙이는 일련번호. 발급은 순서가 보장되는 MainActor 에서만 한다.
    private var cameraGeneration = 0

    public init(canvasDate: CanvasStore.CalendarDate) {
        state = State(canvasDate: canvasDate)
    }

    var previewSource: any CameraPreviewSource {
        cameraSession.previewSource
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .sceneBecameActive:
            resumeCameraIfNeeded()
        case .screenDisappeared, .sceneEnteredBackground:
            suspendCamera()
        case .cameraRetryTapped:
            prepareCamera()
        case .flashTapped:
            state.flashMode = state.flashMode.toggled
        case .cameraPositionTapped:
            switchCamera()
        case .shutterTapped:
            capturePhoto()
        case .retakeTapped:
            state.capturedPhotoData = nil
            state.screen = .camera
            prepareCamera()
        case .photoConfirmed:
            confirmPhoto()
        case .settingsTapped:
            openSystemSettings()
        case .toastDismissed:
            state.showsToast = false
        }
    }

    /// 촬영본이 없는데 넘어가면 빈 화면이 뜨므로 확인 화면에서만 진행한다.
    private func confirmPhoto() {
        guard state.capturedPhotoData != nil else { return }
        state.screen = .analysisLoading
    }

    /// 화면 복귀·재진입 공통 경로. 카메라가 필요 없는 화면이면 세션을 건드리지 않는다.
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

    /// 권한을 확인하고, 미결정이면 요청까지 마친 뒤 진행 가능 여부를 돌려준다.
    /// 거부·제한이면 권한 안내 화면으로 보내고 `false`.
    private func resolveAuthorization() async -> Bool {
        let isAuthorized = switch cameraSession.authorizationStatus() {
        case .authorized: true
        case .notDetermined: await cameraSession.requestAuthorization()
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
        let generation = nextCameraGeneration()
        state.cameraPhase = .idle
        Task { [cameraSession] in
            await cameraSession.stop(generation: generation)
        }
    }

    private func switchCamera() {
        guard !state.isSwitchingCamera, !state.isCapturing else { return }
        state.isSwitchingCamera = true
        cameraSwitchTask = Task { [weak self, cameraSession] in
            let switchedPosition = await cameraSession.switchCamera()
            guard let self else { return }

            state.isSwitchingCamera = false
            guard !Task.isCancelled, let switchedPosition else { return }

            state.cameraPosition = switchedPosition
            // 전면은 플래시 컨트롤 자체가 비활성이라 켜진 채로 남지 않게 되돌린다.
            if switchedPosition == .front {
                state.flashMode = .off
            }
        }
    }

    private func capturePhoto() {
        guard state.isShutterEnabled else { return }

        state.isCapturing = true
        photoCaptureTask = Task { [weak self, cameraSession, flashMode = state.flashMode] in
            let photoData = await cameraSession.capturePhoto(flashMode: flashMode)
            guard let self else { return }

            state.isCapturing = false
            guard !Task.isCancelled, let photoData else { return }

            state.capturedPhotoData = photoData
            state.screen = .cameraConfirmation
            // 확인 화면에서는 세션을 붙들고 있을 이유가 없다.
            await cameraSession.stop(generation: nextCameraGeneration())
        }
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

    /// 취소되지 않았고, 그 사이 더 새로운 요청이 끼어들지도 않았는지.
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
        state.isCapturing = false
    }
}
