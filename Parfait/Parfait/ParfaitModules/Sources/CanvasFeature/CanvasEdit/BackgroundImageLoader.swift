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
    /// 디코딩·크롭·인코딩을 `@concurrent` 로 묶어 전부 호출자 executor 밖에서 처리한다.
    @concurrent
    static func normalizedJPEG(
        _ imageData: Data,
        croppedTo viewFinderRegion: ViewFinderRegion? = nil
    ) async throws -> Data? {
        guard let normalizedImage = try await ImageDownsampling.decodedImage(
            from: imageData,
            maxPixelSize: maximumLongEdge
        ) else { return nil }

        let backgroundImage = viewFinderRegion?.croppedImage(from: normalizedImage) ?? normalizedImage
        return UIImage(cgImage: backgroundImage).jpegData(compressionQuality: jpegCompressionQuality)
    }

    static func galleryJPEG(assetIdentifier: String) async throws -> Data? {
        guard let original = await PhotoLibraryImageSource.originalData(
            assetIdentifier: assetIdentifier
        ) else { return nil }
        // 방향은 `ImageDownsampling` 이 `kCGImageSourceCreateThumbnailWithTransform` 로 적용한다.
        return try await normalizedJPEG(original.photoData)
    }
}
