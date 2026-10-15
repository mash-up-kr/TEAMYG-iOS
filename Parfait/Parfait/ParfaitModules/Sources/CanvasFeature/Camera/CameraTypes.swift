//
//  CameraTypes.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/16/26.
//

import AVFoundation
import Common
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct CameraPreviewFrame: Equatable, @unchecked Sendable {
    let image: CGImage

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.image === rhs.image
    }

    /// 프리즈 프레임은 촬영 직후 확인 화면에 잠깐 띄우는 플레이스홀더라 화면 크기면 충분하다.
    /// 캡처 해상도 그대로 두면 분석이 끝날 때까지 수십 MB 가 State 에 남는다.
    private static let freezeFrameLongEdge: CGFloat = 1280
    private static let jpegCompressionQuality = 0.9

    var freezeFrame: Self {
        Self(image: image.downscaled(longEdge: Self.freezeFrameLongEdge))
    }

    /// 저장용 JPEG. 프레임은 이미 정방향·미러링이 적용돼 있어 방향 메타데이터가 필요 없다.
    @concurrent
    func jpegData() async -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        let options = [kCGImageDestinationLossyCompressionQuality: Self.jpegCompressionQuality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

enum CameraFlashMode: Equatable, Sendable {
    case off
    case enabled

    var toggled: Self {
        self == .off ? .enabled : .off
    }

    var avFoundationTorchMode: AVCaptureDevice.TorchMode {
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
