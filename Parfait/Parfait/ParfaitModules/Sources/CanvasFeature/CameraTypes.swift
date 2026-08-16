//
//  CameraTypes.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/16/26.
//

import Foundation

enum CameraAuthorization: Sendable {
    case authorized
    case notDetermined
    case denied
    case restricted
}

enum CameraFlashMode: Equatable, Sendable {
    case off
    case enabled

    var toggled: Self {
        self == .off ? .enabled : .off
    }
}

enum CameraPosition: Equatable, Sendable {
    case front
    case back
}
