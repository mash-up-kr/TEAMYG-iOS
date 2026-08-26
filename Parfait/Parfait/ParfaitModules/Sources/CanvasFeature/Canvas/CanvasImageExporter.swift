//
//  CanvasImageExporter.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CoreGraphics
import Foundation
import SwiftUI
import UIComponent
import UIKit

/// 캔버스를 한 장의 이미지로 합성한다 — SY-001-Closed 의 `갤러리에 저장` 이 쓴다.
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

    private let toppingRenderer: CanvasToppingRenderer
    private let session: URLSession

    public init(toppingRenderer: CanvasToppingRenderer, session: URLSession = .shared) {
        self.toppingRenderer = toppingRenderer
        self.session = session
    }

    func image(of content: CanvasStore.CanvasContent) async -> UIImage? {
        guard let background = await preparedBackground(content.background) else { return nil }

        var toppings: [PreparedTopping] = []
        for canvasImage in content.images {
            guard let topping = await preparedTopping(canvasImage) else { return nil }
            toppings.append(topping)
        }

        return await render(background: background, toppings: toppings)
    }

    @MainActor
    private func render(background: PreparedBackground, toppings: [PreparedTopping]) -> UIImage? {
        let renderer = ImageRenderer(
            content: CanvasSnapshotView(
                background: background,
                toppings: toppings,
                canvasSize: Self.canvasSize
            )
        )
        renderer.scale = Self.renderScale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func preparedBackground(
        _ background: CanvasStore.CanvasBackground
    ) async -> PreparedBackground? {
        switch background {
        case .color(let hex):
            return .color(hex: hex)

        case .image(let url):
            guard let (imageData, _) = try? await session.data(from: url) else { return nil }
            return decodedBackground(from: imageData)

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
        let neededLongEdge = Self.canvasSize.width
            * CanvasArea.toppingBaseLongSideRatio
            * CGFloat(canvasImage.scale)
            * Self.renderScale
        guard let image = await toppingRenderer.topping(
            at: canvasImage.imageURL,
            neededLongEdge: neededLongEdge
        ) else { return nil }

        var silhouette: CGImage?
        if let border = canvasImage.border, border.width > 0 {
            silhouette = await toppingRenderer.silhouette(
                of: image,
                at: canvasImage.imageURL,
                width: border.width
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
/// `ImageRenderer` 는 `task` 를 기다려 주지 않는다. 배치 규칙은 `CanvasPlacedImage` 와 같아야 한다.
private struct CanvasSnapshotView: View {
    let background: PreparedBackground
    let toppings: [PreparedTopping]
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            backgroundLayer

            ForEach(toppings) { topping in
                toppingLayer(topping)
                    .zIndex(topping.canvasImage.positionZ)
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

    private func toppingLayer(_ topping: PreparedTopping) -> some View {
        let renderedSize = renderedSize(of: topping)

        return ZStack {
            if let silhouette = topping.silhouette, let border = topping.canvasImage.border {
                Image(decorative: silhouette, scale: 1, orientation: .up)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(Color(hex: border.colorHex))
            }

            Image(decorative: topping.image, scale: 1, orientation: .up)
                .resizable()
        }
        .frame(width: renderedSize.width, height: renderedSize.height)
        .rotationEffect(.degrees(topping.canvasImage.rotation))
        .position(
            x: CGFloat(topping.canvasImage.positionX) * canvasSize.width,
            y: CGFloat(topping.canvasImage.positionY) * canvasSize.height
        )
    }

    private func renderedSize(of topping: PreparedTopping) -> CGSize {
        let longSide = canvasSize.width
            * CanvasArea.toppingBaseLongSideRatio
            * CGFloat(topping.canvasImage.scale)

        return CanvasArea.toppingSize(
            pixelSize: CGSize(width: topping.image.width, height: topping.image.height),
            longSide: longSide
        )
    }
}
