//
//  CameraTypes.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/16/26.
//

import AVFoundation

enum CameraAuthorization: Sendable {
    case authorized
    case notDetermined
    case denied
    case restricted

    init(_ status: AVAuthorizationStatus) {
        switch status {
        case .authorized: self = .authorized
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .denied
        }
    }
}

enum CameraFlashMode: Equatable, Sendable {
    case off
    case enabled

    var toggled: Self {
        self == .off ? .enabled : .off
    }

    var avFoundationMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: .off
        case .enabled: .on
        }
    }
}

enum CameraPosition: Equatable, Sendable {
    case front
    case back

    var flipped: Self {
        self == .back ? .front : .back
    }

    var avFoundationPosition: AVCaptureDevice.Position {
        switch self {
        case .front: .front
        case .back: .back
        }
    }
}
