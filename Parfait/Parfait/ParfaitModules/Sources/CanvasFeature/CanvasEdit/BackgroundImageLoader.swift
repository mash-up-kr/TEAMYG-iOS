//
//  BackgroundImageLoader.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import Foundation
import Photos
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
        guard let imageData = await galleryImageData(assetIdentifier: assetIdentifier) else { return nil }
        return await normalizedJPEG(imageData)
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

    private static func galleryImageData(assetIdentifier: String) async -> Data? {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier],
            options: nil
        ).firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { imageData, _, _, _ in
                continuation.resume(returning: imageData)
            }
        }
    }
}
