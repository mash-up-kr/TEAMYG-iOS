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

    /// 디코딩을 백그라운드 태스크로 보내는 async 버전 — 호출부가 `Task.detached` 를 직접 감싸지 않는다.
    /// 디코딩 결과에 크롭·인코딩 같은 CPU 작업을 이어 붙일 때만 sync 버전을 직접 쓴다.
    public static func decodedImage(
        from imageData: Data,
        maxPixelSize: Int,
        applyOrientationTransform: Bool = true
    ) async -> CGImage? {
        // 동기 클로저로 감싸 sync 오버로드를 고른다 — async 컨텍스트에선 async 쪽이 잡혀 재귀가 된다.
        let decode: @Sendable () -> CGImage? = {
            decodedImage(
                from: imageData,
                maxPixelSize: maxPixelSize,
                applyOrientationTransform: applyOrientationTransform
            )
        }
        return await Task.detached(priority: .userInitiated) { decode() }.value
    }
}
