//
//  CameraTypes.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/16/26.
//

import AVFoundation
import CoreGraphics

struct CameraPreviewFrame: Equatable, @unchecked Sendable {
    let image: CGImage

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.image === rhs.image
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
