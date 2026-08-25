//
//  CameraPermission.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/20/26.
//

import AVFoundation

/// 카메라 권한 4분기. 조회·요청은 기기 전역 상태라 세션과 무관하게 값 타입에서 처리한다.
enum CameraPermission: Equatable, Sendable {
    case authorized
    case notDetermined
    case denied
    case restricted

    init(status: AVAuthorizationStatus) {
        switch status {
        case .authorized: self = .authorized
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        default: self = .denied
        }
    }

    /// 현재 권한 상태.
    static func current() -> CameraPermission {
        CameraPermission(status: AVCaptureDevice.authorizationStatus(for: .video))
    }

    /// 미결정 상태에서 시스템 권한 팝업을 띄우고 허용 여부를 반환한다.
    static func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
