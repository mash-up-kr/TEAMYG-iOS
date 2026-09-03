//
//  ToppingMaskRenderer.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import CoreImage

/// 브러시 스트로크를 원본 알파 마스크 위에 다시 칠해 누끼를 새로 합성한다.
/// 스트로크 목록을 매번 처음부터 재생하므로 undo/redo 는 목록만 줄였다 늘리면 된다.
/// 좁아진 추출 캔버스 한 벌. 스트로크 좌표계도 함께 옮겨야 해서 이동량을 같이 돌려준다.
struct TightenedCutout: Sendable {
    let photo: CGImage
    let baseMask: CGImage
    let mask: CGImage
    let image: CGImage
    let strokeOffset: CGPoint
}

actor ToppingMaskRenderer {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func cutout(
        photo: CGImage,
        baseMask: CGImage,
        strokes: [ToppingBrushStroke]
    ) -> (mask: CGImage, image: CGImage)? {
        guard let mask = paint(baseMask: baseMask, strokes: strokes),
              let image = ToppingCutoutCompositor.composite(photo: photo, mask: mask, context: context)
        else { return nil }

        return (mask, image)
    }

    /// 편집이 끝난 마스크에 맞춰 추출 캔버스를 다시 잘라낸다. 지운 영역이 투명 여백으로 남아
    /// 토핑이 실제보다 작게·치우쳐 보이는 것을 막는다. 여백 정책은 C-103 자동 추출과 같다.
    /// 잘라낼 것이 없으면 `nil` — 호출한 쪽이 지금 캔버스를 그대로 쓰면 된다.
    func tightenedCutout(
        photo: CGImage,
        baseMask: CGImage,
        strokes: [ToppingBrushStroke]
    ) -> TightenedCutout? {
        guard let mask = paint(baseMask: baseMask, strokes: strokes),
              let metrics = InstanceMaskScanner.metrics(of: mask)
        else { return nil }

        let canvasBounds = CGRect(x: 0, y: 0, width: mask.width, height: mask.height)
        let cropRect = ObjectExtractionPolicy
            .canvasRect(around: metrics.boundingBox)
            .integral
            .intersection(canvasBounds)
        guard cropRect.width >= 1, cropRect.height >= 1, cropRect != canvasBounds else { return nil }

        guard let croppedPhoto = photo.cropping(to: cropRect),
              let croppedBaseMask = baseMask.cropping(to: cropRect),
              let croppedMask = mask.cropping(to: cropRect),
              let image = ToppingCutoutCompositor.composite(
                  photo: croppedPhoto,
                  mask: croppedMask,
                  context: context
              )
        else { return nil }

        return TightenedCutout(
            photo: croppedPhoto,
            baseMask: croppedBaseMask,
            mask: croppedMask,
            image: image,
            strokeOffset: CGPoint(x: -cropRect.minX, y: -cropRect.minY)
        )
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
