//
//  CanvasGallerySaver.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import Photos
import UIKit

/// 합성한 캔버스를 기기 사진 앨범에 저장한다 — SY-001-Closed 의 `갤러리에 저장`.
///
/// 사진을 읽지 않고 추가만 하므로 `.addOnly` 권한을 요청한다.
/// 권한 거부 전용 화면은 정책 범위 밖이므로(`canvas-policy.md` §8) 거부도 저장 실패로 수렴한다.
enum CanvasGallerySaver {
    static func save(_ image: UIImage) async -> Bool {
        guard await hasAddPermission() else { return false }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            return false
        }
    }

    private static func hasAddPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .notDetermined else { return isGranted(status) }
        return isGranted(await PHPhotoLibrary.requestAuthorization(for: .addOnly))
    }

    /// 앨범 추가는 일부 허용(`.limited`)에서도 막히지 않는다.
    private static func isGranted(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }
}
