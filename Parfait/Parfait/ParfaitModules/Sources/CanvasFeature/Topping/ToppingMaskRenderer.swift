//
//  ToppingMaskRenderer.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import Common
import CoreGraphics
import CoreImage

/// 브러시 스트로크를 원본 알파 마스크 위에 다시 칠해 누끼를 새로 합성한다.
/// 스트로크 목록을 매번 처음부터 재생하므로 undo/redo 는 목록만 줄였다 늘리면 된다.
/// 스트로크를 재생해 새로 합성한 누끼 한 벌.
struct RenderedCutout: Sendable {
    let mask: CGImage
    let image: CGImage
    /// 포함 픽셀이 하나라도 있는지. 비어 있으면 C-104 다음 버튼을 막는 근거가 된다.
    let hasArea: Bool
}

actor ToppingMaskRenderer {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func cutout(
        photo: CGImage,
        baseMask: CGImage,
        strokes: [ToppingBrushStroke]
    ) -> RenderedCutout? {
        guard let mask = paint(baseMask: baseMask, strokes: strokes),
              let image = ToppingCutoutCompositor.composite(photo: photo, mask: mask, context: context)
        else { return nil }

        return RenderedCutout(
            mask: mask,
            image: image,
            hasArea: InstanceMaskScanner.metrics(of: mask) != nil
        )
    }

    /// 편집이 끝난 마스크에 맞춰 편집 캔버스에서 토핑만 잘라낸다. 포함 영역 밖이 투명 여백으로 남아
    /// 토핑이 실제보다 작게·치우쳐 보이는 것을 막는다. 여백 정책은 C-103 자동 추출과 같다.
    /// 포함 영역이 하나도 없으면 `nil`.
    func tightenedCutout(
        photo: CGImage,
        baseMask: CGImage,
        strokes: [ToppingBrushStroke]
    ) -> CGImage? {
        guard let mask = paint(baseMask: baseMask, strokes: strokes),
              let metrics = InstanceMaskScanner.metrics(of: mask)
        else { return nil }

        let canvasBounds = CGRect(x: 0, y: 0, width: mask.width, height: mask.height)
        let cropRect = ObjectExtractionPolicy
            .canvasRect(around: metrics.boundingBox)
            .integral
            .intersection(canvasBounds)
        guard cropRect.width >= 1, cropRect.height >= 1,
              let croppedPhoto = photo.cropping(to: cropRect),
              let croppedMask = mask.cropping(to: cropRect),
              let image = ToppingCutoutCompositor.composite(
                  photo: croppedPhoto,
                  mask: croppedMask,
                  context: context
              )
        else { return nil }

        return image.downscaledPreservingAlpha(longEdge: ObjectExtractionPolicy.extractionCanvasLongEdge)
    }

    private func paint(baseMask: CGImage, strokes: [ToppingBrushStroke]) -> CGImage? {
        let width = baseMask.width
        let height = baseMask.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.draw(baseMask, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for stroke in strokes {
            let gray: CGFloat = stroke.mode == .fill ? 1 : 0
            context.setStrokeColor(gray: gray, alpha: 1)
            context.setFillColor(gray: gray, alpha: 1)
            context.setLineWidth(stroke.diameter)
            draw(stroke, in: context, height: CGFloat(height))
        }

        return context.makeImage()
    }

    /// 스트로크 좌표는 좌상단 원점, `CGContext` 는 좌하단 원점이라 y 를 뒤집는다.
    private func draw(_ stroke: ToppingBrushStroke, in context: CGContext, height: CGFloat) {
        let points = stroke.points.map { CGPoint(x: $0.x, y: height - $0.y) }
        guard let first = points.first else { return }

        guard points.count > 1 else {
            let radius = stroke.diameter / 2
            context.fillEllipse(
                in: CGRect(
                    x: first.x - radius,
                    y: first.y - radius,
                    width: stroke.diameter,
                    height: stroke.diameter
                )
            )
            return
        }

        context.beginPath()
        context.move(to: first)
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }
}
