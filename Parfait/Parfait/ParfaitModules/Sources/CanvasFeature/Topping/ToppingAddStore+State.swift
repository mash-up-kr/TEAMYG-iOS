//
//  ToppingAddStore+State.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/20/26.
//

import Foundation

extension ToppingAddStore {
    public struct State: Equatable, Sendable {
        let canvasDate: CanvasStore.CalendarDate
        var screen: Screen = .camera
        var cameraPhase: CameraPhase = .idle
        var flashMode: CameraFlashMode = .off
        var cameraPosition: CameraPosition = .back
        var capturedPhotoData: Data?
        var showsToast = true
        var isSwitchingCamera = false
        var isCapturing = false

        /// 세션이 돌고 있고 전환·촬영이 진행 중이 아닐 때만 셔터를 연다.
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

        /// 세션이 돌아야 하는 화면인지. 에러 화면은 재시도로 복귀할 수 있어 포함한다.
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
