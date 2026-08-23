//
//  ToppingCutoutCompositor.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import CoreImage

enum ToppingCutoutCompositor {
    static func composite(photo: CGImage, mask: CGImage, context: CIContext) -> CGImage? {
        let source = CIImage(cgImage: photo)
        let cutout = source.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: CIImage.empty(),
                kCIInputMaskImageKey: CIImage(cgImage: mask)
            ]
        )
        return context.createCGImage(cutout, from: source.extent)
    }

    static func drawCanvas(
        _ image: CGImage,
        in drawRect: CGRect,
        canvasSize: CGSize,
        isMask: Bool
    ) -> CGImage? {
        let width = max(1, Int(canvasSize.width.rounded()))
        let height = max(1, Int(canvasSize.height.rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: isMask ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: isMask
                ? CGImageAlphaInfo.none.rawValue
                : CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // 마스크 캔버스의 여백은 검정(=투명)으로 시작한다.
        if isMask {
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        context.interpolationQuality = .high
        context.draw(image, in: drawRect)
        return context.makeImage()
    }
}
