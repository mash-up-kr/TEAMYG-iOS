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
    private static let borderPanelAnimation: Animation = .easeInOut(duration: 0.25)

    let background: CanvasStore.CanvasBackground
    let toppings: [CanvasEditStore.EditableTopping]
    let texts: [CanvasStore.CanvasText]
    let selectedToppingID: Int?
    let onToppingTap: (Int) -> Void
    let onPlacementChange: (Int, ToppingPlacement) -> Void
    let onDeleteTap: (Int) -> Void
    var onBorderPanelDismiss: (() -> Void)?

    @State private var draft = ToppingTransformDraft()
    @State private var toppingPixelSizes: [Int: CGSize] = [:]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // ponytail: 텍스트는 편집 대상이 아니라 배경과 함께 남의 사진 아래에 깐다 — 사진과의 z 순서는 이 화면에서만 무시.
                // 텍스트 편집(3차)이 붙으면 토핑 스택과 합친다.
                CanvasContentView(
                    content: CanvasStore.CanvasContent(background: background, texts: texts)
                )

                toppingStack(otherToppings, canvasSize: proxy.size)

                Color.black25

                toppingStack(myToppings, canvasSize: proxy.size)

                ToppingTransformGestureOverlay(
                    draft: $draft,
                    placementCenter: selectedTopping?.placement.center(in: proxy.size),
                    onSwallowedTouch: onBorderPanelDismiss,
                    onTap: { selectTopping(at: $0, in: proxy.size) },
                    onCommit: { commit($0, in: proxy.size) }
                )

                if let selectedTopping {
                    ToppingDeleteHandle(
                        placement: displayPlacement(of: selectedTopping),
                        canvasSize: proxy.size,
                        toppingPixelSize: toppingPixelSizes[selectedTopping.id] ?? .zero,
                        draft: draft,
                        onDeleteTap: onBorderPanelDismiss ?? { onDeleteTap(selectedTopping.id) }
                    )
                }
            }
            .animation(Self.borderPanelAnimation, value: onBorderPanelDismiss != nil)
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
            ? draft.applied(to: displayPlacement(of: topping), in: canvasSize)
            : topping.placement
    }

    func displayPlacement(of topping: CanvasEditStore.EditableTopping) -> ToppingPlacement {
        guard onBorderPanelDismiss != nil, topping.id == selectedToppingID else { return topping.placement }

        var centered = topping.placement
        centered.positionX = 0.5
        centered.positionY = 0.5
        return centered
    }

    func selectTopping(at point: CGPoint, in canvasSize: CGSize) {
        let isTapped = { (topping: CanvasEditStore.EditableTopping) in
            topping.placement.contains(
                point,
                toppingPixelSize: toppingPixelSizes[topping.id] ?? .zero,
                canvasSize: canvasSize
            )
        }
        if let selectedTopping, isTapped(selectedTopping) {
            onToppingTap(selectedTopping.id)
            return
        }
        guard let tappedTopping = (otherToppings + myToppings).last(where: isTapped) else { return }
        onToppingTap(tappedTopping.id)
    }

    func commit(_ transform: ToppingTransformDraft, in canvasSize: CGSize) {
        guard let selectedTopping else { return }
        onPlacementChange(selectedTopping.id, transform.applied(to: selectedTopping.placement, in: canvasSize))
    }
}
