//
//  BackgroundImageLoader.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import Foundation
import UIKit

enum BackgroundImageLoader {
    private static let maximumLongEdge = 2_048
    private static let jpegCompressionQuality = 0.9

    static func cameraJPEG(
        photoData: Data,
        viewFinderRegion: ViewFinderRegion?
    ) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let normalizedImage = ImageDownsampling.decodedImage(
                from: photoData,
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

    static func recentUploadJPEG(_ imageData: Data) async -> Data? {
        await normalizedJPEG(imageData)
    }

    private static func normalizedJPEG(_ imageData: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let normalizedImage = ImageDownsampling.decodedImage(
                from: imageData,
                maxPixelSize: maximumLongEdge
            ) else { return nil }
            return UIImage(cgImage: normalizedImage).jpegData(compressionQuality: jpegCompressionQuality)
        }.value
    }
}
