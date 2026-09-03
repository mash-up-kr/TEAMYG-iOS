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
    private static let selectionStrokeWidth: CGFloat = 2

    let topping: CGImage
    let silhouette: CGImage?
    let borderColor: Color?
    let placement: ToppingPlacement
    let canvasSize: CGSize
    var isSelected = false
    var onTap: (() -> Void)?

    var body: some View {
        ZStack {
            if let silhouette, let borderColor {
                Image(decorative: silhouette, scale: 1, orientation: .up)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(borderColor)
            }

            Image(decorative: topping, scale: 1, orientation: .up)
                .resizable()
        }
        .frame(width: renderedSize.width, height: renderedSize.height)
        .overlay {
            if isSelected {
                Rectangle()
                    .strokeBorder(.whiteFixed, lineWidth: Self.selectionStrokeWidth)
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
