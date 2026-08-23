//
//  ImageDownsampling.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import Foundation
import ImageIO

enum ImageDownsampling {
    static func decodedImage(from imageData: Data, maxPixelSize: Int) -> CGImage? {
        guard maxPixelSize > 0,
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil)
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }
}

extension CGSize {
    func longEdgePixelSize(scale: CGFloat) -> Int {
        Int((max(width, height) * scale).rounded(.up))
    }
}
