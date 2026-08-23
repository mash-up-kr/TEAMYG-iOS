//
//  InstanceMaskScanner.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/22/26.
//

import CoreGraphics
import CoreVideo
import Foundation

struct InstanceMaskMetrics: Equatable, Sendable {
    let maskSize: CGSize
    let boundingBox: CGRect
    let foregroundPixelCount: Int

    var areaRatio: Double {
        let totalPixelCount = Double(maskSize.width * maskSize.height)
        guard totalPixelCount > 0 else { return 0 }
        return Double(foregroundPixelCount) / totalPixelCount
    }

    var normalizedBoundingBox: CGRect {
        guard maskSize.width > 0, maskSize.height > 0 else { return .zero }
        return CGRect(
            x: boundingBox.minX / maskSize.width,
            y: boundingBox.minY / maskSize.height,
            width: boundingBox.width / maskSize.width,
            height: boundingBox.height / maskSize.height
        )
    }
}

enum InstanceMaskScanner {
    private typealias ForegroundTest = (_ rowStart: UnsafeRawPointer, _ column: Int) -> Bool

    static func metrics(of maskBuffer: CVPixelBuffer) -> InstanceMaskMetrics? {
        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        guard width > 0, height > 0 else { return nil }

        guard let isForeground = foregroundTest(for: CVPixelBufferGetPixelFormatType(maskBuffer)) else { return nil }
        guard CVPixelBufferLockBaseAddress(maskBuffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(maskBuffer) else { return nil }

        return scan(
            baseAddress: baseAddress,
            bytesPerRow: CVPixelBufferGetBytesPerRow(maskBuffer),
            width: width,
            height: height,
            isForeground: isForeground
        )
    }

    private static func foregroundTest(for pixelFormat: OSType) -> ForegroundTest? {
        switch pixelFormat {
        case kCVPixelFormatType_OneComponent8:
            return { rowStart, column in
                rowStart.load(fromByteOffset: column, as: UInt8.self) >= 128
            }
        case kCVPixelFormatType_OneComponent16Half:
            return { rowStart, column in
                let byteOffset = column * MemoryLayout<Float16>.size
                return rowStart.loadUnaligned(fromByteOffset: byteOffset, as: Float16.self) >= 0.5
            }
        case kCVPixelFormatType_OneComponent32Float:
            return { rowStart, column in
                let byteOffset = column * MemoryLayout<Float>.size
                return rowStart.loadUnaligned(fromByteOffset: byteOffset, as: Float.self) >= 0.5
            }
        default:
            return nil
        }
    }

    private static func scan(
        baseAddress: UnsafeRawPointer,
        bytesPerRow: Int,
        width: Int,
        height: Int,
        isForeground: ForegroundTest
    ) -> InstanceMaskMetrics? {
        var minimumX = width
        var minimumY = height
        var maximumX = -1
        var maximumY = -1
        var foregroundPixelCount = 0

        for row in 0..<height {
            let rowStart = baseAddress.advanced(by: row * bytesPerRow)
            var rowMinimumX = width
            var rowMaximumX = -1

            for column in 0..<width where isForeground(rowStart, column) {
                foregroundPixelCount += 1
                if column < rowMinimumX { rowMinimumX = column }
                rowMaximumX = column
            }

            guard rowMaximumX >= 0 else { continue }
            if rowMinimumX < minimumX { minimumX = rowMinimumX }
            if rowMaximumX > maximumX { maximumX = rowMaximumX }
            if row < minimumY { minimumY = row }
            maximumY = row
        }

        guard foregroundPixelCount > 0, maximumX >= 0, maximumY >= 0 else { return nil }

        return InstanceMaskMetrics(
            maskSize: CGSize(width: width, height: height),
            boundingBox: CGRect(
                x: CGFloat(minimumX),
                y: CGFloat(minimumY),
                width: CGFloat(maximumX - minimumX + 1),
                height: CGFloat(maximumY - minimumY + 1)
            ),
            foregroundPixelCount: foregroundPixelCount
        )
    }
}
