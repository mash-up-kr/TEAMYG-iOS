//
//  ViewFinderRegion.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics

struct ViewFinderRegion: Equatable, Sendable {
    private let previewSize: CGSize
    private let frame: CGRect

    init?(previewFrame: CGRect, viewFinderFrame: CGRect) {
        guard previewFrame.width > 0, previewFrame.height > 0,
              viewFinderFrame.width > 0, viewFinderFrame.height > 0
        else { return nil }

        previewSize = previewFrame.size
        frame = viewFinderFrame.offsetBy(dx: -previewFrame.minX, dy: -previewFrame.minY)
    }

    func normalizedRect(inSourceOfSize sourceSize: CGSize) -> CGRect? {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let fillScale = max(previewSize.width / sourceSize.width, previewSize.height / sourceSize.height)
        let displayedSize = CGSize(
            width: sourceSize.width * fillScale,
            height: sourceSize.height * fillScale
        )
        let displayedOrigin = CGPoint(
            x: (previewSize.width - displayedSize.width) / 2,
            y: (previewSize.height - displayedSize.height) / 2
        )

        let normalizedRect = CGRect(
            x: (frame.minX - displayedOrigin.x) / displayedSize.width,
            y: (frame.minY - displayedOrigin.y) / displayedSize.height,
            width: frame.width / displayedSize.width,
            height: frame.height / displayedSize.height
        ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))

        guard !normalizedRect.isNull, normalizedRect.width > 0, normalizedRect.height > 0 else { return nil }
        return normalizedRect
    }

    var previewCoverageRatio: CGFloat {
        guard previewSize.width > 0, previewSize.height > 0 else { return 1 }
        let coverage = min(frame.width / previewSize.width, frame.height / previewSize.height)
        return min(max(coverage, 0.1), 1)
    }

    func croppedImage(from image: CGImage) -> CGImage? {
        let sourceSize = CGSize(width: image.width, height: image.height)
        guard let normalizedRect = normalizedRect(inSourceOfSize: sourceSize) else { return nil }

        let pixelRect = CGRect(
            x: normalizedRect.minX * sourceSize.width,
            y: normalizedRect.minY * sourceSize.height,
            width: normalizedRect.width * sourceSize.width,
            height: normalizedRect.height * sourceSize.height
        )
        .integral
        .intersection(CGRect(origin: .zero, size: sourceSize))

        guard pixelRect.width >= 1, pixelRect.height >= 1 else { return nil }
        return image.cropping(to: pixelRect)
    }
}
