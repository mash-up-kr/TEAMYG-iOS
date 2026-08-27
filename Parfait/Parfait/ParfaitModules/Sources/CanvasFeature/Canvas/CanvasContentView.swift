//
//  CanvasContentView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

struct CanvasContentView: View {
    let content: CanvasStore.CanvasContent
    var onImageTap: ((CanvasStore.CanvasImage) -> Void)?

    init(
        content: CanvasStore.CanvasContent,
        onImageTap: ((CanvasStore.CanvasImage) -> Void)? = nil
    ) {
        self.content = content
        self.onImageTap = onImageTap
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background

                ForEach(content.images) { canvasImage in
                    CanvasPlacedImage(
                        canvasImage: canvasImage,
                        canvasSize: proxy.size,
                        onTap: imageTapAction(for: canvasImage)
                    )
                        .zIndex(canvasImage.positionZ)
                }
            }
        }
        .clipped()
    }

    private func imageTapAction(for canvasImage: CanvasStore.CanvasImage) -> (() -> Void)? {
        guard let onImageTap else { return nil }
        return { onImageTap(canvasImage) }
    }

    @ViewBuilder
    private var background: some View {
        switch content.background {
        case .color(let hex):
            Color(hex: hex)

        case .image(let url):
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    ProgressView()
                        .tint(.gray500)
                case .failure:
                    Color.gray100
                @unknown default:
                    Color.gray100
                }
            }

        case .imageData(let imageData):
            LocalCanvasBackgroundImage(imageData: imageData)
        }
    }
}

private struct LocalCanvasBackgroundImage: View {
    let imageData: Data

    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray100
                }
            }
            .task(id: DecodeRequest(size: proxy.size, displayScale: displayScale)) {
                let maxPixelSize = proxy.size.longEdgePixelSize(scale: displayScale)
                image = await Task.detached(priority: .userInitiated) {
                    ImageDownsampling.decodedImage(from: imageData, maxPixelSize: maxPixelSize)
                }.value
            }
        }
    }

    private struct DecodeRequest: Equatable {
        let size: CGSize
        let displayScale: CGFloat
    }
}

/// 테두리는 이미지에 굽지 않고 색·굵기로만 저장되므로(확정 규약), 알파 실루엣을 떠서 토핑 뒤에 깐다.
/// C-105·C-106 미리보기와 같은 `ToppingBorderRenderer` 를 타야 저장 전후 모습이 같다.
struct CanvasPlacedImage: View {
    let canvasImage: CanvasStore.CanvasImage
    let canvasSize: CGSize
    var isSelected = false
    var onTap: (() -> Void)?
    var onToppingLoaded: ((CGSize) -> Void)?

    @Environment(\.canvasToppingRenderer) private var renderer
    @Environment(\.displayScale) private var displayScale
    @State private var topping: CGImage?
    @State private var silhouette: CGImage?
    @State private var isLoading = true

    var body: some View {
        content
            .task(id: LoadKey(canvasImage, decodeLongEdge: decodeLongEdge)) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let topping {
            CanvasToppingLayer(
                topping: topping,
                silhouette: silhouette,
                borderColor: canvasImage.border.map { Color(hex: $0.colorHex) },
                placement: placement,
                canvasSize: canvasSize,
                isSelected: isSelected,
                onTap: onTap
            )
        } else if isLoading {
            ProgressView()
                .tint(.gray500)
                .position(placement.center(in: canvasSize))
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        // 렌더러는 캔버스 화면이 주입한다. 주입이 없으면 그릴 수단이 없다.
        // 레이아웃 전(캔버스 크기 0)에는 필요 해상도를 모른다 — 크기가 정해지면 `task` 가 다시 돈다.
        guard let renderer, neededLongEdgePixels > 0 else { return }

        // 이미 그려 둔 이미지는 새 해상도가 도착할 때까지 그대로 둔다 — 확대 중 깜빡이지 않게.
        let loaded = await renderer.topping(
            at: canvasImage.imageURL,
            neededLongEdge: neededLongEdgePixels
        )
        guard !Task.isCancelled else { return }
        topping = loaded
        if let loaded {
            onToppingLoaded?(CGSize(width: loaded.width, height: loaded.height))
        }

        guard let loaded, let border = canvasImage.border, border.width > 0 else {
            silhouette = nil
            return
        }
        let rendered = await renderer.silhouette(of: loaded, at: canvasImage.imageURL, width: border.width)
        guard !Task.isCancelled else { return }
        silhouette = rendered
    }

    private var placement: ToppingPlacement {
        ToppingPlacement(canvasImage)
    }

    private var longSide: CGFloat {
        placement.longSide(in: canvasSize)
    }

    /// 화면에 그려질 긴 변의 픽셀 수. 짧은 변은 원본 비율을 따라가므로 이 값만으로 필요 해상도가 정해진다 —
    /// 이미지를 받기 전에도 계산할 수 있어 "받아 보고 크기를 정하는" 순환을 피한다.
    private var neededLongEdgePixels: CGFloat {
        longSide * displayScale
    }

    private var decodeLongEdge: CGFloat {
        ToppingDecodeBucket.longEdge(covering: neededLongEdgePixels)
    }

    /// 확대해서 버킷이 올라가면 다시 받아야 하므로 해상도도 키에 넣는다.
    /// 버킷 안에서 배율만 오르내리는 동안에는 값이 그대로라 재디코딩이 일어나지 않는다.
    private struct LoadKey: Equatable {
        let imageURL: URL
        let border: CanvasStore.CanvasImageBorder?
        let decodeLongEdge: CGFloat

        init(_ canvasImage: CanvasStore.CanvasImage, decodeLongEdge: CGFloat) {
            imageURL = canvasImage.imageURL
            border = canvasImage.border
            self.decodeLongEdge = decodeLongEdge
        }
    }
}
