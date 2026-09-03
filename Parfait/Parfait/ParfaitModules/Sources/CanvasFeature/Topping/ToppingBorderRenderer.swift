//
//  ToppingBorderRenderer.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import CoreImage

actor ToppingBorderRenderer {
    /// `source` 는 실루엣을 뜬 이미지를 가리키는 이름 — 편집 중이면 후보 번호, 서버 토핑이면 이미지 URL 이다.
    private struct CacheKey: Hashable {
        let source: String
        let widthPerMyriad: Int

        var width: Double { Double(widthPerMyriad) / 10_000 }
    }

    private static let previewLongEdge: CGFloat = 1200

    private let context = CIContext(options: [.cacheIntermediates: false])
    private var cache: [CacheKey: CGImage] = [:]

    func silhouette(of topping: ExtractedTopping, width: Double) -> CGImage? {
        silhouette(of: topping.image, source: "candidate-\(topping.candidateID)", width: width)
    }

    /// 알파 실루엣을 굵기만큼 바깥으로 부풀린 테두리 판. 색은 그릴 때 `.template` 로 입힌다.
    /// 굵기는 토핑 긴 변 대비 비율이라(`canvas-policy.md` §5.7) 어떤 크기로 그려도 같은 두께로 보인다.
    func silhouette(of image: CGImage, source sourceName: String, width: Double) -> CGImage? {
        let key = CacheKey(
            source: sourceName,
            widthPerMyriad: Int((width * 10_000).rounded())
        )
        if let cached = cache[key] {
            return cached
        }

        let source = CIImage(cgImage: image)
        let scale = min(1, Self.previewLongEdge / max(source.extent.width, source.extent.height))
        let scaled = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let longEdge = max(scaled.extent.width, scaled.extent.height)
        let dilated = scaled.applyingFilter(
            "CIMorphologyMaximum",
            parameters: [kCIInputRadiusKey: key.width * longEdge]
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
