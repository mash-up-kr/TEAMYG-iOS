//
//  CanvasToppingLayer.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/27/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

/// 화면(`CanvasPlacedImage`)과 갤러리 저장본(`CanvasImageExporter`)이 같은 그림을 내도록 배치 규칙을 한곳에 둔다.
struct CanvasToppingLayer: View {
    let topping: CGImage
    let silhouette: CGImage?
    let borderColor: Color?
    let borderWidth: CGFloat
    let placement: ToppingPlacement
    let canvasSize: CGSize
    var isSelected = false
    var onTap: (() -> Void)?

    var body: some View {
        ToppingBorderedImage(
            topping: topping,
            silhouette: silhouette,
            borderColor: borderColor,
            borderWidth: borderWidth,
            size: renderedSize
        )
        .overlay {
            if isSelected {
                ToppingSelectionFrame(renderedSize: renderedSize)
            }
        }
        .contentShape(.rect)
        .onTapGesture { onTap?() }
        .allowsHitTesting(onTap != nil)
        .rotationEffect(.degrees(placement.rotationDegrees))
        .position(placement.center(in: canvasSize))
    }

    private var renderedSize: CGSize {
        placement.renderedSize(
            toppingPixelSize: CGSize(width: topping.width, height: topping.height),
            canvasSize: canvasSize
        )
    }
}

extension CanvasToppingLayer {
    /// 저장된 토핑(`CanvasImage`)을 그릴 때 — 테두리 값을 색·두께로 풀어 넘긴다.
    init(
        topping: CGImage,
        silhouette: CGImage?,
        border: CanvasStore.CanvasImageBorder?,
        placement: ToppingPlacement,
        canvasSize: CGSize,
        isSelected: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.init(
            topping: topping,
            silhouette: silhouette,
            borderColor: border.map { Color(hex: $0.colorHex) },
            borderWidth: border.map { CGFloat($0.width) } ?? 0,
            placement: placement,
            canvasSize: canvasSize,
            isSelected: isSelected,
            onTap: onTap
        )
    }
}

struct ToppingBorderedImage: View {
    let topping: CGImage
    let silhouette: CGImage?
    let borderColor: Color?
    let borderWidth: CGFloat
    let size: CGSize

    var body: some View {
        ZStack {
            if let silhouette, let borderColor {
                Image(decorative: silhouette, scale: 1, orientation: .up)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(borderColor)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(x: plateScale.width, y: plateScale.height)
            }

            Image(decorative: topping, scale: 1, orientation: .up)
                .resizable()
                .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
    }

    private var plateScale: CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: 1, height: 1) }

        let expansion = borderWidth * 2
        return CGSize(
            width: (size.width + expansion) / size.width,
            height: (size.height + expansion) / size.height
        )
    }
}
