//
//  ToppingImageEncoder.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/24/26.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 누끼를 알파가 살아 있는 PNG 로 인코딩한다. 서버에 올리는 형식이자 최근 업로드 로컬 저장 형식이다.
enum ToppingImageEncoder {
    /// 업로드 상한. 긴 변이 이보다 크면 비율을 유지한 채 줄인다.
    static let maximumLongEdge: CGFloat = 1500

    /// 최근 업로드로 보관해 둔 알파 PNG 를 다시 읽어들인다.
    static func decode(_ imageData: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// 원본 크기 비트맵을 만들지 않고 `longEdge` 로 줄이며 디코딩한다.
    /// `CGImage.downscaled(longEdge:)` 와 달리 알파를 보존하므로 누끼에 쓸 수 있다.
    static func decode(_ imageData: Data, longEdge: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(longEdge.rounded()))
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func encodePNG(_ image: CGImage) -> Data? {
        let resized = image.downscaled(longEdge: maximumLongEdge)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, resized, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
