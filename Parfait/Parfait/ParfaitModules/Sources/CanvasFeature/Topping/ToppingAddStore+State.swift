//
//  ToppingAddStore+State.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/20/26.
//

import Foundation

extension ToppingAddStore {
    struct State: Equatable, Sendable {
        let canvasDate: CalendarDate
        var screen: Screen = .camera
        var cameraPhase: CameraPhase = .idle
        var flashMode: CameraFlashMode = .off
        var cameraPosition: CameraPosition = .back
        var capturedPhotoData: Data?
        var showsToast = true
        var isSwitchingCamera = false
        var isCapturing = false

        var isCameraReady: Bool {
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

    enum Intent {
        case screenAppeared
        case screenDisappeared
        case sceneBecameActive
        case sceneEnteredBackground
        case toastDismissed
        case flashTapped
        case cameraPositionTapped
        case shutterTapped
        case retakeTapped
        case photoConfirmed
        case cameraRetryTapped
        case settingsTapped
    }

    enum Screen: Equatable, Sendable {
        case camera
        case cameraConfirmation
        case cameraPermissionError
        case cameraUnavailable
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
}
