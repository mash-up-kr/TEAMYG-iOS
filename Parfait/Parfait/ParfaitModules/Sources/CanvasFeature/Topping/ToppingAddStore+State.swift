//
//  ToppingAddStore+State.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/20/26.
//

import CoreGraphics
import Foundation

extension ToppingAddStore {
    struct State: Equatable, Sendable {
        let canvasDate: CalendarDate
        let photoSource: PhotoSource
        var screen: Screen
        var cameraPhase: CameraPhase = .idle
        var flashMode: CameraFlashMode = .off
        var cameraPosition: CameraPosition = .back
        var photoCapturePhase: PhotoCapturePhase = .idle
        var capturedViewFinderRegion: ViewFinderRegion?
        var galleryAssetIdentifier: String?
        var analysis: PhotoAnalysis?
        var extractedTopping: ExtractedTopping?
        var showsToast = true
        var isSwitchingCamera = false

        init(canvasDate: CalendarDate, photoSource: PhotoSource) {
            self.canvasDate = canvasDate
            self.photoSource = photoSource
            screen = photoSource.entryScreen
        }

        var isCameraReady: Bool {
            cameraPhase == .running && !isSwitchingCamera && photoCapturePhase == .idle
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

        var capturedPhotoData: Data? {
            guard case .ready(_, let photoData) = photoCapturePhase else { return nil }
            return photoData
        }

        var cameraPreviewFrame: CameraPreviewFrame? {
            switch photoCapturePhase {
            case .processing(let previewFrame), .ready(let previewFrame, _):
                previewFrame
            case .idle:
                nil
            }
        }

        var isRetakeEnabled: Bool {
            if case .ready = photoCapturePhase { true } else { false }
        }

        var isNextEnabled: Bool {
            photoCapturePhase != .idle
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
        case shutterTapped(viewFinderRegion: ViewFinderRegion?)
        case retakeTapped
        case photoConfirmed
        case galleryPhotoConfirmed(assetIdentifier: String)
        case cameraRetryTapped
        case settingsTapped
        case analysisCancelled
        case candidateTapped(normalizedPoint: CGPoint)
        case candidateSelectionBackTapped
        case analysisErrorClosed
        case cutoutResultClosed
        case photoEditTapped
        case cutoutConfirmed
    }

    enum PhotoSource: Equatable, Sendable {
        case camera
        case gallery

        var entryScreen: Screen {
            switch self {
            case .camera: .camera
            case .gallery: .gallery
            }
        }

        var confirmScreen: Screen {
            switch self {
            case .camera: .cameraConfirmation
            case .gallery: .gallery
            }
        }
    }

    enum Screen: Equatable, Sendable {
        case camera
        case cameraConfirmation
        case cameraPermissionError
        case cameraUnavailable
        case gallery
        case analysisLoading
        case analysisError
        case candidateSelection
        case cutoutResult

        var isCameraError: Bool {
            self == .cameraPermissionError || self == .cameraUnavailable
        }

        var needsRunningCamera: Bool {
            self == .camera || isCameraError
        }

        var isAnalysisScreen: Bool {
            switch self {
            case .analysisLoading, .analysisError, .candidateSelection, .cutoutResult: true
            default: false
            }
        }
    }

    enum CameraPhase: Equatable, Sendable {
        case idle
        case preparing
        case running
        case permissionDenied
        case unavailable
    }

    enum PhotoCapturePhase: Equatable, Sendable {
        case idle
        case processing(previewFrame: CameraPreviewFrame?)
        case ready(previewFrame: CameraPreviewFrame?, photoData: Data)
    }
}
