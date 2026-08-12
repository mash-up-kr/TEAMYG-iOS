//
//  PhotoLibraryPermission.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import Photos

/// 앨범 권한 3분기. `.restricted` 는 거부로 수렴한다 (스펙: 별도 에러 UI 없음).
public enum PhotoLibraryPermission: Equatable, Sendable {
    case fullAccess
    case limited
    case denied
    case notDetermined

    public init(status: PHAuthorizationStatus) {
        switch status {
        case .authorized: self = .fullAccess
        case .limited: self = .limited
        case .notDetermined: self = .notDetermined
        default: self = .denied
        }
    }

    /// 현재 권한 상태 (readWrite 기준).
    public static func current() -> PhotoLibraryPermission {
        PhotoLibraryPermission(status: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    /// 미결정 상태에서 시스템 권한 팝업을 띄우고 결과를 반환한다.
    public static func request() async -> PhotoLibraryPermission {
        PhotoLibraryPermission(status: await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }
}
