//
//  CanvasImageExporter.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import Core
import CoreGraphics
import Foundation
import SwiftUI
import UIComponent
import UIKit

/// 캔버스를 한 장의 이미지로 합성한다 — C-001-Save-Preview 가 띄우고 그대로 앨범에 넣는 그 이미지다.
///
/// 저장본에는 잘린 모서리와 날짜 헤더를 넣지 않고 직사각형 Canvas-Area 만 담는다 (`canvas-policy.md` §4.3).
/// 배경·토핑을 모두 받아 둔 뒤 한 번에 그리므로, 하나라도 못 받으면 저장을 실패로 돌린다 —
/// 빠진 토핑이 있는 캔버스를 앨범에 남기지 않기 위해서다.
public struct CanvasImageExporter: Sendable {
    /// 저장본 크기. 16:9 Canvas-Area 를 3배 배율로 그려 1080 × 1920 픽셀이 된다.
    private static let canvasSize = CGSize(width: 360, height: 640)
    private static let renderScale: CGFloat = 3
    /// 배경 사진은 저장본 픽셀 크기(1920)보다 조금 여유 있게 받아 둔다.
    private static let backgroundLongEdgePixelSize = 2160
    /// 영상 저장본 — 토핑이 `toppingAppearWindow` 안에서 배열 순서대로 하나씩 튀어나오고, 남은 시간은 완성본을 보여 준다.
    private static let videoDuration: Double = 2
    private static let videoFramesPerSecond: Int32 = 30
    private static let toppingAppearWindow: Double = 1.5
    private static let toppingPopDuration: Double = 0.25

    private let toppingRenderer: CanvasToppingRenderer
    private let imageProvider: ImageProvider

    public init(toppingRenderer: CanvasToppingRenderer, imageProvider: ImageProvider) {
        self.toppingRenderer = toppingRenderer
        self.imageProvider = imageProvider
    }

    func image(of content: CanvasStore.CanvasContent) async -> UIImage? {
        guard let (background, toppings) = await prepared(content) else { return nil }
        return await renderImage(background: background, toppings: toppings)
    }

    /// 2초짜리 mp4 를 임시 폴더에 쓰고 그 주소를 돌려준다. 파일 정리는 받는 쪽 몫이다.
    func video(of content: CanvasStore.CanvasContent) async -> URL? {
        guard let (background, toppings) = await prepared(content) else { return nil }
        return await renderVideo(background: background, toppings: toppings)
    }

    /// 토핑별 등장 진행도(0...1). `count` 개를 `toppingAppearWindow` 에 고르게 나눠 차례로 띄운다.
    static func toppingProgresses(count: Int, at time: Double) -> [Double] {
        (0..<count).map { order in
            let startTime = toppingAppearWindow * Double(order) / Double(count)
            return min(max((time - startTime) / toppingPopDuration, 0), 1)
        }
    }

    private func prepared(
        _ content: CanvasStore.CanvasContent
    ) async -> (PreparedBackground, [PreparedTopping])? {
        async let loadedBackground = preparedBackground(content.background)
        async let loadedToppings = preparedToppings(content.images)

        guard let background = await loadedBackground,
              let toppings = await loadedToppings
        else { return nil }
        return (background, toppings)
    }

    private func preparedToppings(
        _ canvasImages: [CanvasStore.CanvasImage]
    ) async -> [PreparedTopping]? {
        await withTaskGroup(of: PreparedTopping?.self) { group in
            for canvasImage in canvasImages {
                group.addTask { await self.preparedTopping(canvasImage) }
            }

            var prepared: [PreparedTopping] = []
            for await topping in group {
                guard let topping else {
                    group.cancelAll()
                    return nil
                }
                prepared.append(topping)
            }
            return prepared.sorted { $0.canvasImage.positionZ < $1.canvasImage.positionZ }
        }
    }

    @MainActor
    private func renderImage(background: PreparedBackground, toppings: [PreparedTopping]) -> UIImage? {
        renderer(background: background, toppings: toppings).uiImage
    }

    @MainActor
    private func renderer(
        background: PreparedBackground,
        toppings: [PreparedTopping],
        toppingProgresses: [Double]? = nil
    ) -> ImageRenderer<CanvasSnapshotView> {
        let renderer = ImageRenderer(
            content: CanvasSnapshotView(
                background: background,
                toppings: toppings,
                toppingProgresses: toppingProgresses,
                canvasSize: Self.canvasSize
            )
        )
        renderer.scale = Self.renderScale
        renderer.isOpaque = true
        return renderer
    }

    @MainActor
    private func renderVideo(background: PreparedBackground, toppings: [PreparedTopping]) async -> URL? {
        let pixelSize = CGSize(
            width: Self.canvasSize.width * Self.renderScale,
            height: Self.canvasSize.height * Self.renderScale
        )
        guard let writer = CanvasVideoWriter(
            pixelSize: pixelSize,
            framesPerSecond: Self.videoFramesPerSecond
        ) else { return nil }

        let frameCount = Int(Self.videoDuration * Double(Self.videoFramesPerSecond))
        var previousProgresses: [Double]?
        var previousFrame: CGImage?

        for frameIndex in 0..<frameCount {
            let time = Double(frameIndex) / Double(Self.videoFramesPerSecond)
            let progresses = Self.toppingProgresses(count: toppings.count, at: time)
            // 토핑이 다 나온 뒤처럼 그림이 그대로면 다시 그리지 않는다.
            if progresses != previousProgresses {
                previousFrame = renderer(
                    background: background,
                    toppings: toppings,
                    toppingProgresses: progresses
                ).cgImage
                previousProgresses = progresses
            }

            guard !Task.isCancelled,
                  let frame = previousFrame,
                  await writer.append(frame, at: frameIndex)
            else {
                writer.cancel()
                return nil
            }
        }
        return await writer.finish()
    }

    private func preparedBackground(
        _ background: CanvasStore.CanvasBackground
    ) async -> PreparedBackground? {
        switch background {
        case .color(let hex):
            return .color(hex: hex)

        case .image(let url):
            guard let image = await imageProvider.image(
                at: url,
                maxPixelSize: Self.backgroundLongEdgePixelSize
            ) else { return nil }
            return .image(image)

        case .imageData(let imageData):
            return decodedBackground(from: imageData)
        }
    }

    private func decodedBackground(from imageData: Data) -> PreparedBackground? {
        guard let image = ImageDownsampling.decodedImage(
            from: imageData,
            maxPixelSize: Self.backgroundLongEdgePixelSize
        ) else { return nil }
        return .image(image)
    }

    private func preparedTopping(_ canvasImage: CanvasStore.CanvasImage) async -> PreparedTopping? {
        // 저장본에 그려질 크기로만 받는다 — 화면과 같은 식이되 배율이 `renderScale` 이다.
        let longSide = ToppingPlacement(canvasImage).longSide(in: Self.canvasSize)
        guard let image = await toppingRenderer.topping(
            at: canvasImage.imageURL,
            neededLongEdge: longSide * Self.renderScale
        ) else { return nil }

        var silhouette: CGImage?
        if let border = canvasImage.border, border.width > 0 {
            silhouette = await toppingRenderer.silhouette(
                of: image,
                at: canvasImage.imageURL,
                width: border.width,
                renderedLongEdge: longSide
            )
        }

        return PreparedTopping(canvasImage: canvasImage, image: image, silhouette: silhouette)
    }
}

private enum PreparedBackground {
    case color(hex: String)
    case image(CGImage)
}

private struct PreparedTopping: Identifiable {
    let canvasImage: CanvasStore.CanvasImage
    let image: CGImage
    let silhouette: CGImage?

    var id: Int { canvasImage.id }
}

/// 저장본 한 장. 이미지를 모두 받아 둔 뒤에 그리므로 `CanvasContentView` 와 달리 비동기 로딩이 없다 —
/// `ImageRenderer` 는 `task` 를 기다려 주지 않는다.
private struct CanvasSnapshotView: View {
    let background: PreparedBackground
    let toppings: [PreparedTopping]
    /// 영상 프레임일 때 토핑별 등장 진행도(0...1, `toppings` 와 같은 순서). `nil` 이면 전부 다 보인다.
    let toppingProgresses: [Double]?
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            backgroundLayer

            // 이미 positionZ 오름차순으로 정렬해 넘긴다 — 배열 순서가 곧 쌓임 순서다.
            ForEach(Array(toppings.enumerated()), id: \.element.id) { order, topping in
                let progress = toppingProgresses?[order] ?? 1
                toppingLayer(topping)
                    .opacity(progress)
                    // `CanvasToppingLayer` 가 캔버스 전체를 차지하고 `position` 으로 놓이므로 토핑 중심을 축으로 키운다.
                    .scaleEffect(0.6 + 0.4 * Self.easeOutBack(progress), anchor: anchor(of: topping))
                    .zIndex(Double(order))
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch background {
        case .color(let hex):
            Color(hex: hex)

        case .image(let image):
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .scaledToFill()
                .frame(width: canvasSize.width, height: canvasSize.height)
                .clipped()
        }
    }

    private func anchor(of topping: PreparedTopping) -> UnitPoint {
        let center = ToppingPlacement(topping.canvasImage).center(in: canvasSize)
        return UnitPoint(x: center.x / canvasSize.width, y: center.y / canvasSize.height)
    }

    /// 살짝 넘쳤다 돌아오는 팝 느낌.
    private static func easeOutBack(_ progress: Double) -> Double {
        let overshoot = 1.70158
        let shifted = progress - 1
        return 1 + (overshoot + 1) * pow(shifted, 3) + overshoot * pow(shifted, 2)
    }

    private func toppingLayer(_ topping: PreparedTopping) -> some View {
        CanvasToppingLayer(
            topping: topping.image,
            silhouette: topping.silhouette,
            borderColor: topping.canvasImage.border.map { Color(hex: $0.colorHex) },
            borderWidth: topping.canvasImage.border.map { CGFloat($0.width) } ?? 0,
            placement: ToppingPlacement(topping.canvasImage),
            canvasSize: canvasSize
        )
    }
}
