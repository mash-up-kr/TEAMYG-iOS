//
//  ToppingBorderRenderer.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import CoreImage

actor ToppingBorderRenderer {
    private struct CacheKey: Hashable {
        let candidateID: Int
        let width: Int
    }

    private static let previewLongEdge: CGFloat = 1200

    private let context = CIContext(options: [.cacheIntermediates: false])
    private var cache: [CacheKey: CGImage] = [:]

    func silhouette(of topping: ExtractedTopping, width: Double) -> CGImage? {
        let key = CacheKey(candidateID: topping.candidateID, width: Int(width.rounded()))
        if let cached = cache[key] {
            return cached
        }

        let source = CIImage(cgImage: topping.image)
        let scale = min(1, Self.previewLongEdge / max(source.extent.width, source.extent.height))
        let scaled = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let dilated = scaled.applyingFilter(
            "CIMorphologyMaximum",
            parameters: [kCIInputRadiusKey: Double(key.width) * scale]
        )

        guard let rendered = context.createCGImage(dilated, from: scaled.extent) else { return nil }

        if cache.count > 16 {
            cache.removeAll()
        }
        cache[key] = rendered
        return rendered
    }

    func reset() {
        cache.removeAll()
    }
}
