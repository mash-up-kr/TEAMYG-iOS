//
//  ToppingSelectionFrame.swift
//  CanvasFeature
//
//  Created by 박서연 on 9/7/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

struct ToppingSelectionFrame: View {
    private static let marginRatioPerSide: CGFloat = 0.0556
    private static let minimumMargin: CGFloat = 4
    private static let strokeWidth: CGFloat = 2
    private static let dashPattern: [CGFloat] = [7.5, 9]

    let renderedSize: CGSize

    static func size(around renderedSize: CGSize) -> CGSize {
        CGSize(
            width: renderedSize.width + 2 * margin(alongside: renderedSize.width),
            height: renderedSize.height + 2 * margin(alongside: renderedSize.height)
        )
    }

    private static func margin(alongside length: CGFloat) -> CGFloat {
        max(length * marginRatioPerSide, minimumMargin)
    }

    var body: some View {
        let size = Self.size(around: renderedSize)

        Rectangle()
            .strokeBorder(
                Color.whiteFixed,
                style: StrokeStyle(lineWidth: Self.strokeWidth, dash: Self.dashPattern)
            )
            .frame(width: size.width, height: size.height)
    }
}
