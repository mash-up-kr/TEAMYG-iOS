//
//  ToppingBorderRenderer.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import CoreImage
import Foundation

actor ToppingBorderRenderer {
    /// `source` 는 실루엣을 뜬 이미지를 가리키는 이름 — 편집 중이면 후보 번호, 서버 토핑이면 이미지 URL 이다.
    /// 팽창 반경은 정수 픽셀로 끊어 두고 렌더에도 끊은 값을 써야, 캐시가 내주는 그림과 키가 어긋나지 않는다.
    private struct CacheKey {
        let source: String
        let radiusPixels: Int
        let workingLongEdge: Int

        init(source: String, radius: CGFloat, workingLongEdge: CGFloat) {
            self.source = source
            radiusPixels = Int(radius.rounded())
            self.workingLongEdge = Int(workingLongEdge.rounded())
        }

        var radius: CGFloat { CGFloat(radiusPixels) }
        var identifier: NSString { "\(source)#\(workingLongEdge)#\(radiusPixels)" as NSString }
    }

    private static let previewLongEdge: CGFloat = 1200
    /// 실루엣 총량 상한. 토핑과 같은 크기의 판이라 장수가 아니라 바이트로 잡는다.
    private static let cacheByteLimit = 24 * 1024 * 1024

    private let context = CIContext(options: [.cacheIntermediates: false])
    /// 메모리 경고 때 스스로 비우도록 `NSCache` 를 쓴다.
    private let cache = NSCache<NSString, CGImage>()

    init() {
        cache.totalCostLimit = Self.cacheByteLimit
    }

    func silhouette(
        of topping: ExtractedTopping,
        width: Double,
        renderedLongEdge: CGFloat
    ) -> CGImage? {
        silhouette(
            of: topping.image,
            source: "candidate-\(topping.candidateID)",
            width: width,
            renderedLongEdge: renderedLongEdge
        )
    }

    /// 알파 실루엣을 굵기만큼 바깥으로 부풀린 테두리 판. 색은 그릴 때 `.template` 로 입힌다.
    /// 굵기는 화면 절대 두께(pt)라(`canvas-policy.md` §5.7) 그려질 긴 변을 함께 받아야 반경이 정해진다.
    func silhouette(
        of image: CGImage,
        source sourceName: String,
        width: Double,
        renderedLongEdge: CGFloat
    ) -> CGImage? {
        guard renderedLongEdge > 0 else { return nil }

        let source = CIImage(cgImage: image)
        let sourceLongEdge = max(source.extent.width, source.extent.height)
        let growth = 1 + 2 * CGFloat(width) / renderedLongEdge
        let scale = min(1, Self.previewLongEdge / (sourceLongEdge * growth))
        let scaled = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let key = CacheKey(
            source: sourceName,
            radius: CGFloat(width) / renderedLongEdge * max(scaled.extent.width, scaled.extent.height),
            workingLongEdge: max(scaled.extent.width, scaled.extent.height)
        )
        if let cached = cache.object(forKey: key.identifier) {
            return cached
        }

        let dilated = scaled.applyingFilter(
            "CIMorphologyMaximum",
            parameters: [kCIInputRadiusKey: key.radius]
        )
        let bounds = scaled.extent.insetBy(dx: -key.radius, dy: -key.radius)

        guard let rendered = context.createCGImage(dilated, from: bounds) else { return nil }

        cache.setObject(rendered, forKey: key.identifier, cost: rendered.byteCount)
        return rendered
    }

    func reset() {
        cache.removeAllObjects()
    }
}
