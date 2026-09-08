//
//  BackgroundImageLoader.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import Core
import Foundation
import UIKit

enum BackgroundImageLoader {
    private static let maximumLongEdge = 2_048
    private static let jpegCompressionQuality = 0.7

    /// 손에 든 사진 데이터를 캔버스 배경 JPEG 으로 정규화한다. `croppedTo` 는 촬영 화면의 뷰파인더 밖을 잘라낸다.
    /// 디코딩·크롭·인코딩을 한 detached 태스크에 묶는다 — `ImageDownsampling` 의 async 버전을 쓰면
    /// 디코딩만 내려가고 크롭·인코딩은 호출자 executor 에 남는다(= 메인 히치 위험).
    static func normalizedJPEG(
        _ imageData: Data,
        croppedTo viewFinderRegion: ViewFinderRegion? = nil
    ) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let normalizedImage = ImageDownsampling.decodedImage(
                from: imageData,
                maxPixelSize: maximumLongEdge
            ) else { return nil }

            let backgroundImage = viewFinderRegion?.croppedImage(from: normalizedImage) ?? normalizedImage
            return UIImage(cgImage: backgroundImage).jpegData(compressionQuality: jpegCompressionQuality)
        }.value
    }

    static func galleryJPEG(assetIdentifier: String) async -> Data? {
        guard let original = await PhotoLibraryImageSource.originalData(
            assetIdentifier: assetIdentifier
        ) else { return nil }
        // 방향은 `ImageDownsampling` 이 `kCGImageSourceCreateThumbnailWithTransform` 로 적용한다.
        return await normalizedJPEG(original.photoData)
    }
}
