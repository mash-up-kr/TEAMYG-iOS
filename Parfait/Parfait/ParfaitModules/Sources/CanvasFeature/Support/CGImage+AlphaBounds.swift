//
//  CGImage+AlphaBounds.swift
//  CanvasFeature
//
//  Created by 박서연 on 9/5/26.
//

import CoreGraphics

extension CGImage {
    func croppedRemovingSymmetricMargin() -> CGImage {
        guard let bounds = opaqueBounds() else { return self }

        let horizontal = min(bounds.minX, CGFloat(width) - bounds.maxX).rounded(.down)
        let vertical = min(bounds.minY, CGFloat(height) - bounds.maxY).rounded(.down)
        guard horizontal >= 1 || vertical >= 1 else { return self }

        let cropped = CGRect(x: 0, y: 0, width: width, height: height)
            .insetBy(dx: horizontal, dy: vertical)
        guard cropped.width >= 1, cropped.height >= 1 else { return self }

        return cropping(to: cropped) ?? self
    }

    func opaqueBounds(threshold: UInt8 = 8) -> CGRect? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let raw = context.data else { return nil }

        let alpha = raw.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = context.bytesPerRow

        func rowHasPixel(_ row: Int) -> Bool {
            (0..<width).contains { alpha[row * bytesPerRow + $0] > threshold }
        }
        func columnHasPixel(_ column: Int, rows: ClosedRange<Int>) -> Bool {
            rows.contains { alpha[$0 * bytesPerRow + column] > threshold }
        }

        guard let top = (0..<height).first(where: rowHasPixel) else { return nil }
        let bottom = (top..<height).last(where: rowHasPixel) ?? top
        let left = (0..<width).first { columnHasPixel($0, rows: top...bottom) } ?? 0
        let right = (left..<width).last { columnHasPixel($0, rows: top...bottom) } ?? left

        return CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    }
}
