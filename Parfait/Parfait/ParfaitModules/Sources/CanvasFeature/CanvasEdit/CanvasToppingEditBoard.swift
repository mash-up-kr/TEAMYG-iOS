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
    /// 선택된 토핑은 항상 맨 위. 나머지는 배열 순서로 쌓는다(서버 `positionZ` 값과 축을 섞지 않는다).
    private static let selectedZIndex: Double = 1_000_000

    let background: CanvasStore.CanvasBackground
    let toppings: [CanvasEditStore.EditableTopping]
    let selectedToppingID: Int?
    let onToppingTap: (Int) -> Void
    let onPlacementChange: (Int, ToppingPlacement) -> Void
    let onDeleteTap: (Int) -> Void
    var onTouchBegan: (() -> Void)?

    @State private var draft = ToppingTransformDraft()
    @State private var toppingPixelSizes: [Int: CGSize] = [:]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CanvasContentView(
                    content: CanvasStore.CanvasContent(background: background, images: [])
                )

                toppingStack(otherToppings, canvasSize: proxy.size)

                Color.black25

                toppingStack(myToppings, canvasSize: proxy.size)

                ToppingTransformGestureOverlay(
                    draft: $draft,
                    placementCenter: selectedTopping?.placement.center(in: proxy.size),
                    onTouchBegan: onTouchBegan,
                    onTap: { selectTopping(at: $0, in: proxy.size) },
                    onCommit: { commit($0, in: proxy.size) }
                )

                if let selectedTopping {
                    ToppingDeleteHandle(
                        placement: selectedTopping.placement,
                        canvasSize: proxy.size,
                        toppingPixelSize: toppingPixelSizes[selectedTopping.id] ?? .zero,
                        draft: draft,
                        onDeleteTap: { onDeleteTap(selectedTopping.id) }
                    )
                }
            }
        }
        .canvasBoardFrame()
    }

    private func toppingStack(
        _ toppings: [CanvasEditStore.EditableTopping],
        canvasSize: CGSize
    ) -> some View {
        ZStack {
            ForEach(Array(toppings.enumerated()), id: \.element.id) { order, topping in
                CanvasPlacedImage(
                    canvasImage: topping.canvasImage(placement: previewPlacement(of: topping, in: canvasSize)),
                    canvasSize: canvasSize,
                    isSelected: topping.id == selectedToppingID,
                    onToppingLoaded: { toppingPixelSizes[topping.id] = $0 }
                )
                .zIndex(topping.id == selectedToppingID ? Self.selectedZIndex : Double(order))
            }
        }
    }
}

private extension CanvasToppingEditBoard {
    var myToppings: [CanvasEditStore.EditableTopping] {
        toppings.filter(\.isMine)
    }

    var otherToppings: [CanvasEditStore.EditableTopping] {
        toppings.filter { !$0.isMine }
    }

    var selectedTopping: CanvasEditStore.EditableTopping? {
        myToppings.first { $0.id == selectedToppingID }
    }

    func previewPlacement(of topping: CanvasEditStore.EditableTopping, in canvasSize: CGSize) -> ToppingPlacement {
        topping.id == selectedToppingID
            ? draft.applied(to: topping.placement, in: canvasSize)
            : topping.placement
    }

    func selectTopping(at point: CGPoint, in canvasSize: CGSize) {
        let isTapped = { (topping: CanvasEditStore.EditableTopping) in
            topping.placement.contains(
                point,
                toppingPixelSize: toppingPixelSizes[topping.id] ?? .zero,
                canvasSize: canvasSize
            )
        }
        if let selectedTopping, isTapped(selectedTopping) { return }
        guard let tappedTopping = (otherToppings + myToppings).last(where: isTapped) else { return }
        onToppingTap(tappedTopping.id)
    }

    func commit(_ transform: ToppingTransformDraft, in canvasSize: CGSize) {
        guard let selectedTopping else { return }
        onPlacementChange(selectedTopping.id, transform.applied(to: selectedTopping.placement, in: canvasSize))
    }
}
