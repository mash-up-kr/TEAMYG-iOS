//
//  PhotoLibraryImageSource.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

import CoreGraphics
import ImageIO
import Photos

/// 앨범 원본 로드. 누끼 분석(`ObjectExtractor`)과 배경 이미지 준비(`BackgroundImageLoader`)가
/// 같은 사진을 같은 방식으로 세우도록 한곳에 둔다 — 경로가 갈리면 한쪽에만 회전 버그가 난다.
enum PhotoLibraryImageSource {
    static func originalData(
        assetIdentifier: String
    ) async -> (photoData: Data, orientation: CGImagePropertyOrientation)? {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier],
            options: nil
        ).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { photoData, _, orientation, _ in
                guard let photoData else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (photoData, orientation))
            }
        }
    }
}
