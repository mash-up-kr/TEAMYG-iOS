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
public struct CanvasImageExporter: Sendable {
    /// 저장본 크기. 9:16 Canvas-Area 를 3배 배율로 그려 1080 × 1920 픽셀이 된다.
    private static let canvasSize = CGSize(width: 360, height: 640)
    private static let renderScale: CGFloat = 3
    /// 배경 사진은 저장본 픽셀 크기(1920)보다 조금 여유 있게 받아 둔다.
    private static let backgroundLongEdgePixelSize = 2160
    /// 영상 저장본 — 토핑(이미지·텍스트)이 `toppingAppearWindow` 안에서 쌓인 순서대로 하나씩 효과 없이 나타나고, 남은 시간은 완성본을 보여 준다.
    private static let videoDuration: Double = 2
    private static let videoFramesPerSecond: Int32 = 30
    private static let toppingAppearWindow: Double = 1.5

    private let toppingRenderer: CanvasToppingRenderer
    private let imageProvider: ImageProvider

    public init(toppingRenderer: CanvasToppingRenderer, imageProvider: ImageProvider) {
        self.toppingRenderer = toppingRenderer
        self.imageProvider = imageProvider
    }

    func image(of content: CanvasStore.CanvasContent) async -> UIImage? {
        guard let (background, layers) = await prepared(content) else { return nil }
        return await renderImage(background: background, layers: layers)
    }

    /// 2초짜리 mp4 를 임시 폴더에 쓰고 그 주소를 돌려준다. 파일 정리는 받는 쪽 몫이다.
    func video(of content: CanvasStore.CanvasContent) async -> URL? {
        guard let (background, layers) = await prepared(content) else { return nil }
        return await renderVideo(background: background, layers: layers)
    }

    /// 토핑별 노출 여부. `count` 개를 `toppingAppearWindow` 에 고르게 나눠 차례로 띄운다.
    static func toppingVisibilities(count: Int, at time: Double) -> [Bool] {
        (0..<count).map { order in
            time >= toppingAppearWindow * Double(order) / Double(count)
        }
    }

    /// 이미지만 내려받는다 — 텍스트는 받을 것이 없어 그대로 끼워 넣는다.
    private func prepared(
        _ content: CanvasStore.CanvasContent
    ) async -> (PreparedBackground, [PreparedLayer])? {
        async let loadedBackground = preparedBackground(content.background)
        async let loadedToppings = preparedToppings(content.images)

        guard let background = await loadedBackground,
              let toppings = await loadedToppings
        else { return nil }

        let toppingsByID = Dictionary(uniqueKeysWithValues: toppings.map { ($0.id, $0) })
        let layers = content.layers.compactMap { layer -> PreparedLayer? in
            switch layer {
            case .image(let canvasImage): toppingsByID[canvasImage.id].map(PreparedLayer.image)
            case .text(let canvasText): .text(canvasText)
            }
        }
        return (background, layers)
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
            return prepared
        }
    }

    @MainActor
    private func renderImage(background: PreparedBackground, layers: [PreparedLayer]) -> UIImage? {
        renderer(background: background, layers: layers).uiImage
    }

    @MainActor
    private func renderer(
        background: PreparedBackground,
        layers: [PreparedLayer],
        toppingVisibilities: [Bool]? = nil
    ) -> ImageRenderer<CanvasSnapshotView> {
        let renderer = ImageRenderer(
            content: CanvasSnapshotView(
                background: background,
                layers: layers,
                toppingVisibilities: toppingVisibilities,
                canvasSize: Self.canvasSize
            )
        )
        renderer.scale = Self.renderScale
        renderer.isOpaque = true
        return renderer
    }

    @MainActor
    private func renderVideo(background: PreparedBackground, layers: [PreparedLayer]) async -> URL? {
        let pixelSize = CGSize(
            width: Self.canvasSize.width * Self.renderScale,
            height: Self.canvasSize.height * Self.renderScale
        )
        guard let writer = CanvasVideoWriter(
            pixelSize: pixelSize,
            framesPerSecond: Self.videoFramesPerSecond
        ) else { return nil }

        let frameCount = Int(Self.videoDuration * Double(Self.videoFramesPerSecond))
        var previousVisibilities: [Bool]?
        var previousFrame: CGImage?

        for frameIndex in 0..<frameCount {
            let time = Double(frameIndex) / Double(Self.videoFramesPerSecond)
            let visibilities = Self.toppingVisibilities(count: layers.count, at: time)
            // 새 토핑이 나오지 않아 그림이 그대로면 다시 그리지 않는다.
            if visibilities != previousVisibilities {
                previousFrame = renderer(
                    background: background,
                    layers: layers,
                    toppingVisibilities: visibilities
                ).cgImage
                previousVisibilities = visibilities
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
            do {
                silhouette = try await toppingRenderer.silhouette(
                    of: image,
                    at: canvasImage.imageURL,
                    width: border.width,
                    renderedLongEdge: longSide
                )
            } catch {
                return nil
            }
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

/// 저장본에 쌓는 한 장 — `positionZ` 오름차순으로 넘긴다.
private enum PreparedLayer: Identifiable {
    case image(PreparedTopping)
    case text(CanvasStore.CanvasText)

    var id: CanvasLayer.LayerID {
        switch self {
        case .image(let topping): .image(topping.id)
        case .text(let canvasText): .text(canvasText.id)
        }
    }

}

/// 저장본 한 장. 이미지를 모두 받아 둔 뒤에 그리므로 `CanvasContentView` 와 달리 비동기 로딩이 없다 —
/// `ImageRenderer` 는 `task` 를 기다려 주지 않는다.
private struct CanvasSnapshotView: View {
    let background: PreparedBackground
    let layers: [PreparedLayer]
    /// 영상 프레임일 때 토핑별 노출 여부 (`layers` 와 같은 순서). `nil` 이면 전부 다 보인다.
    let toppingVisibilities: [Bool]?
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            backgroundLayer

            // 이미 positionZ 오름차순으로 정렬해 넘긴다 — 배열 순서가 곧 쌓임 순서다.
            ForEach(Array(layers.enumerated()), id: \.element.id) { order, layer in
                if toppingVisibilities?[order] ?? true {
                    layerView(layer)
                        .zIndex(Double(order))
                }
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

    @ViewBuilder
    private func layerView(_ layer: PreparedLayer) -> some View {
        switch layer {
        case .image(let topping):
            CanvasToppingLayer(
                topping: topping.image,
                silhouette: topping.silhouette,
                border: topping.canvasImage.border,
                placement: ToppingPlacement(topping.canvasImage),
                canvasSize: canvasSize
            )
        case .text(let canvasText):
            CanvasPlacedText(canvasText: canvasText, canvasSize: canvasSize)
        }
    }
}
