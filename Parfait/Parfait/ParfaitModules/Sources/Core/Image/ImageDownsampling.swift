//
//  ImageDownsampling.swift
//  Core
//
//  Created by 김남수 on 9/7/26.
//

import CoreGraphics
import Foundation
import ImageIO

/// 원본 크기 비트맵을 만들지 않고 `maxPixelSize` 로 줄이며 디코딩한다. 알파는 보존된다.
public enum ImageDownsampling {
    /// - Parameters:
    ///   - maxPixelSize: 결과 비트맵 긴 변의 상한(픽셀).
    ///   - applyOrientationTransform: EXIF 방향을 디코딩 단계에서 적용할지.
    ///     사진은 `true`, 방향 정보가 없는 누끼 PNG 처럼 그대로 읽어야 하면 `false`.
    public static func decodedImage(
        from imageData: Data,
        maxPixelSize: Int,
        applyOrientationTransform: Bool = true
    ) -> CGImage? {
        guard maxPixelSize > 0,
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil)
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: applyOrientationTransform,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }
}

extension CGSize {
    /// 이 크기(포인트)가 화면 배율에서 차지하는 긴 변의 픽셀 수 — 다운샘플링 상한 계산용.
    public func longEdgePixelSize(scale: CGFloat) -> Int {
        Int((max(width, height) * scale).rounded(.up))
    }
}
