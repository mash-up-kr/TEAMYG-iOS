//
//  CGImage+Downscaling.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics

extension CGImage {
    /// 긴 변이 `longEdge` 이하가 되도록 축소한 사본. 이미 작으면 자기 자신을 돌려준다.
    /// 알파를 버리므로 불투명 사진에만 쓴다. 누끼에는 `downscaledPreservingAlpha(longEdge:)` 를 쓴다.
    func downscaled(longEdge: CGFloat) -> CGImage {
        redrawn(longEdge: longEdge, alphaInfo: .noneSkipLast)
    }

    /// 알파를 보존하며 축소한 사본. 누끼처럼 투명 영역이 의미를 갖는 이미지에 쓴다.
    func downscaledPreservingAlpha(longEdge: CGFloat) -> CGImage {
        redrawn(longEdge: longEdge, alphaInfo: .premultipliedLast)
    }

    private func redrawn(longEdge: CGFloat, alphaInfo: CGImageAlphaInfo) -> CGImage {
        let scale = min(1, longEdge / CGFloat(max(width, height)))
        guard scale < 1 else { return self }

        let targetWidth = max(1, Int((CGFloat(width) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(height) * scale).rounded()))
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: alphaInfo.rawValue
        ) else {
            return self
        }

        context.interpolationQuality = .high
        context.draw(self, in: CGRect(x: 0, y: 0, width: CGFloat(targetWidth), height: CGFloat(targetHeight)))
        return context.makeImage() ?? self
    }
}
