//
//  CanvasToppingEditBoard.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

struct CanvasToppingEditBoard: View {
    private static let canvasSpace = "CanvasToppingEditBoard"
    /// 선택된 토핑은 항상 맨 위. 나머지는 배열 순서로 쌓는다(서버 `positionZ` 값과 축을 섞지 않는다).
    private static let selectedZIndex: Double = 1_000_000

    let background: CanvasStore.CanvasBackground
    let toppings: [CanvasEditStore.EditableTopping]
    let selectedToppingID: Int?
    let onToppingTap: (Int) -> Void
    let onPlacementChange: (Int, ToppingPlacement) -> Void
    let onDeleteTap: (Int) -> Void
    let onBorderEditTap: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CanvasContentView(
                    content: CanvasStore.CanvasContent(
                        background: background,
                        images: toppings.filter { !$0.isMine }.map(\.canvasImage)
                    ),
                    onImageTap: { onToppingTap($0.id) }
                )

                Color.black25
                    .allowsHitTesting(false)

                ForEach(Array(toppings.filter(\.isMine).enumerated()), id: \.element.id) { order, topping in
                    CanvasEditableTopping(
                        topping: topping,
                        canvasSize: proxy.size,
                        coordinateSpace: Self.canvasSpace,
                        isSelected: topping.id == selectedToppingID,
                        onTap: { onToppingTap(topping.id) },
                        onPlacementChange: { onPlacementChange(topping.id, $0) },
                        onDeleteTap: { onDeleteTap(topping.id) },
                        onBorderEditTap: { onBorderEditTap(topping.id) }
                    )
                    .zIndex(topping.id == selectedToppingID ? Self.selectedZIndex : Double(order))
                }
            }
            .coordinateSpace(.named(Self.canvasSpace))
        }
        .canvasBoardFrame()
    }
}

private struct CanvasEditableTopping: View {
    let topping: CanvasEditStore.EditableTopping
    let canvasSize: CGSize
    let coordinateSpace: String
    let isSelected: Bool
    let onTap: () -> Void
    let onPlacementChange: (ToppingPlacement) -> Void
    let onDeleteTap: () -> Void
    let onBorderEditTap: () -> Void

    @State private var toppingPixelSize: CGSize = .zero
    @State private var draft = ToppingTransformDraft()

    var body: some View {
        ZStack {
            CanvasPlacedImage(
                canvasImage: topping.canvasImage(placement: previewPlacement),
                canvasSize: canvasSize,
                isSelected: isSelected,
                onToppingLoaded: { toppingPixelSize = $0 }
            )

            toppingHitTarget

            if isSelected {
                ToppingEditHandles(
                    placement: topping.placement,
                    canvasSize: canvasSize,
                    toppingPixelSize: toppingPixelSize,
                    coordinateSpace: coordinateSpace,
                    draft: $draft,
                    onCommit: commit,
                    onDeleteTap: onDeleteTap,
                    onBorderEditTap: onBorderEditTap
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private var toppingHitTarget: some View {
        Group {
            if isSelected {
                ToppingTransformGestureOverlay(draft: $draft, onTap: onTap, onCommit: commit)
            } else {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture(perform: onTap)
            }
        }
        .frame(width: renderedSize.width, height: renderedSize.height)
        .rotationEffect(.degrees(previewPlacement.rotationDegrees))
        .position(center)
    }

}

private extension CanvasEditableTopping {
    var previewPlacement: ToppingPlacement {
        draft.applied(to: topping.placement, in: canvasSize)
    }

    var renderedSize: CGSize {
        previewPlacement.renderedSize(
            toppingPixelSize: toppingPixelSize,
            canvasSize: canvasSize
        )
    }

    var center: CGPoint {
        previewPlacement.center(in: canvasSize)
    }

    func commit(_ transform: ToppingTransformDraft) {
        onPlacementChange(transform.applied(to: topping.placement, in: canvasSize))
    }
}
