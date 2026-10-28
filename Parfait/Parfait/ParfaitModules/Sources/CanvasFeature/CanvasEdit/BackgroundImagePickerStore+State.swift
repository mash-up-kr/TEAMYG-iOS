//
//  BackgroundImagePickerStore+State.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import Foundation

extension BackgroundImagePickerStore {
    struct State: Equatable, Sendable {
        let dateText: String
        let weekdayText: String
        let photoSource: PhotoSource
        var screen: Screen
        var isPreparingImage = false
        var showsQuitPopup = false

        init(dateText: String, weekdayText: String, photoSource: PhotoSource) {
            self.dateText = dateText
            self.weekdayText = weekdayText
            self.photoSource = photoSource
            screen = photoSource.entryScreen
        }

    }

    struct Dependencies: Sendable {
        let onImageSelected: @MainActor @Sendable (Data, PhotoSource) -> Void
        let onClose: @MainActor @Sendable () -> Void
    }

    enum PhotoSource: Hashable, Identifiable, Sendable {
        case camera
        case gallery

        var id: Self { self }

        var entryScreen: Screen {
            switch self {
            case .camera: .camera
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

        var isCameraError: Bool {
            self == .cameraPermissionError || self == .cameraUnavailable
        }

        var needsRunningCamera: Bool {
            self == .camera || isCameraError
        }
    }

    enum Event: Sendable {
        case imagePreparationFailed
    }

    enum Intent {
        case screenAppeared
        case screenDisappeared
        case sceneBecameActive
        case sceneEnteredBackground
        /// 촬영·촬영 확인 화면의 조작 (`CameraCaptureScreen`).
        case camera(CameraCaptureScreen.Action)
        case galleryPhotoConfirmed(assetIdentifier: String)
        case cameraRetryTapped
        case settingsTapped
        case closeTapped
        case quitPopupVisibilityChanged(Bool)
        case quitConfirmed
    }
}
