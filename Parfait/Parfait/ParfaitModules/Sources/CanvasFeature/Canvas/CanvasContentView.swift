//
//  CanvasContentView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

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

private struct CanvasPlacedImage: View {
    let canvasImage: CanvasStore.CanvasImage
    let canvasSize: CGSize

    var body: some View {
        AsyncImage(url: canvasImage.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .modifier(CanvasImageBorderModifier(border: canvasImage.border, longSide: longSide))
            case .empty:
                ProgressView()
                    .tint(.gray500)
            case .failure:
                EmptyView()
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: longSide, height: longSide)
        .rotationEffect(.degrees(canvasImage.rotation))
        .position(center)
    }

    private var longSide: CGFloat {
        canvasSize.width * CanvasArea.toppingBaseLongSideRatio * CGFloat(canvasImage.scale)
    }

    private var center: CGPoint {
        CGPoint(
            x: CGFloat(canvasImage.positionX) * canvasSize.width,
            y: CGFloat(canvasImage.positionY) * canvasSize.height
        )
    }
}

/// 실제 토핑 테두리는 누끼의 알파 실루엣을 따라 바깥으로 자라는 외곽선이다.
/// 아래 사각 테두리는 캔버스 기본 화면을 먼저 완성하기 위한 자리표시자이며, 저장 파이프라인 작업에서 교체한다.
private struct CanvasImageBorderModifier: ViewModifier {
    let border: CanvasStore.CanvasImageBorder?
    let longSide: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if let border, border.width > 0 {
            content
                .overlay {
                    Rectangle()
                        .strokeBorder(Color(hex: border.colorHex), lineWidth: CGFloat(border.width) * longSide)
                }
        } else {
            content
        }
    }
}
