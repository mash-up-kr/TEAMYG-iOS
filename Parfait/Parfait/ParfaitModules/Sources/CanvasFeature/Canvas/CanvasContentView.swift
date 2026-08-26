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
    @State private var topping: CGImage?
    @State private var silhouette: CGImage?
    @State private var isLoading = true

    var body: some View {
        content
            .contentShape(.rect)
            .onTapGesture { onTap?() }
            .allowsHitTesting(onTap != nil)
            .rotationEffect(.degrees(canvasImage.rotation))
            .position(center)
            .task(id: LoadKey(canvasImage)) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let topping {
            ZStack {
                if let silhouette, let border = canvasImage.border {
                    Image(decorative: silhouette, scale: 1, orientation: .up)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(Color(hex: border.colorHex))
                }

                Image(decorative: topping, scale: 1, orientation: .up)
                    .resizable()
            }
            .frame(width: renderedSize.width, height: renderedSize.height)
            .overlay {
                if isSelected {
                    Rectangle()
                        .strokeBorder(.whiteFixed, lineWidth: 2)
                }
            }
        } else if isLoading {
            ProgressView()
                .tint(.gray500)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        // 렌더러는 캔버스 화면이 주입한다. 주입이 없으면 그릴 수단이 없다.
        guard let renderer else { return }

        let loaded = await renderer.topping(at: canvasImage.imageURL)
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

    private var longSide: CGFloat {
        canvasSize.width * CanvasArea.toppingBaseLongSideRatio * CGFloat(canvasImage.scale)
    }

    private var renderedSize: CGSize {
        guard let topping else { return CGSize(width: longSide, height: longSide) }

        return CanvasArea.toppingSize(
            pixelSize: CGSize(width: topping.width, height: topping.height),
            longSide: longSide
        )
    }

    private var center: CGPoint {
        CGPoint(
            x: CGFloat(canvasImage.positionX) * canvasSize.width,
            y: CGFloat(canvasImage.positionY) * canvasSize.height
        )
    }

    private struct LoadKey: Equatable {
        let imageURL: URL
        let border: CanvasStore.CanvasImageBorder?

        init(_ canvasImage: CanvasStore.CanvasImage) {
            imageURL = canvasImage.imageURL
            border = canvasImage.border
        }
    }
}
