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

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background

                ForEach(content.images) { canvasImage in
                    CanvasPlacedImage(canvasImage: canvasImage, canvasSize: proxy.size)
                        .zIndex(canvasImage.positionZ)
                }
            }
        }
        .clipped()
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
        }
    }
}

/// 테두리는 이미지에 굽지 않고 색·굵기로만 저장되므로(확정 규약), 알파 실루엣을 떠서 토핑 뒤에 깐다.
/// C-105·C-106 미리보기와 같은 `ToppingBorderRenderer` 를 타야 저장 전후 모습이 같다.
private struct CanvasPlacedImage: View {
    let canvasImage: CanvasStore.CanvasImage
    let canvasSize: CGSize

    @Environment(\.canvasToppingRenderer) private var renderer
    @State private var topping: CGImage?
    @State private var silhouette: CGImage?
    @State private var isLoading = true

    var body: some View {
        content
            .rotationEffect(.degrees(canvasImage.rotation))
            .position(center)
            .task(id: canvasImage) { await load() }
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
        } else if isLoading {
            ProgressView()
                .tint(.gray500)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        let loaded = await renderer.topping(at: canvasImage.imageURL)
        guard !Task.isCancelled else { return }
        topping = loaded

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
}
