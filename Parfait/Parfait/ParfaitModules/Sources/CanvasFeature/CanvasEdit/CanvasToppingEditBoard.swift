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
    let texts: [CanvasEditStore.EditableText]
    let selectedToppingID: Int?
    let selectedTextID: Int?
    let onToppingTap: (Int) -> Void
    let onPlacementChange: (Int, ToppingPlacement) -> Void
    let onDeleteTap: (Int) -> Void
    let onTextTap: (Int) -> Void
    let onTextPlacementChange: (Int, ToppingPlacement) -> Void
    let onTextDeleteTap: (Int) -> Void
    /// 아무것도 없는 곳을 탭했다 — 선택을 푼다. 겹친 것 중 아래 것을 고르려면 먼저 풀어야 한다.
    let onEmptyTap: () -> Void
    var onBorderPanelDismiss: (() -> Void)?

    @State private var draft = ToppingTransformDraft()
    @State private var toppingPixelSizes: [Int: CGSize] = [:]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // ponytail: 남의 텍스트는 배경과 함께 남의 사진 아래에 깐다 — 남의 사진과의 z 순서는 이 화면에서만 무시.
                CanvasContentView(
                    content: CanvasStore.CanvasContent(
                        background: background,
                        texts: otherTexts.map(\.saved)
                    )
                )

                toppingStack(otherToppings, canvasSize: proxy.size)

                Color.black25

                myLayerStack(canvasSize: proxy.size)

                ToppingTransformGestureOverlay(
                    draft: $draft,
                    placementCenter: selectedTopping?.placement.center(in: proxy.size)
                        ?? selectedText?.placement.center(in: proxy.size),
                    onSwallowedTouch: onBorderPanelDismiss,
                    onTap: { select(at: $0, in: proxy.size) },
                    onCommit: { commit($0, in: proxy.size) }
                )

                if let selectedTopping {
                    ToppingDeleteHandle(
                        placement: displayPlacement(of: selectedTopping),
                        canvasSize: proxy.size,
                        renderedSize: { placement in
                            placement.renderedSize(
                                toppingPixelSize: toppingPixelSizes[selectedTopping.id] ?? .zero,
                                canvasSize: proxy.size
                            )
                        },
                        draft: draft,
                        onDeleteTap: onBorderPanelDismiss ?? { onDeleteTap(selectedTopping.id) }
                    )
                } else if let selectedText {
                    ToppingDeleteHandle(
                        placement: selectedText.placement,
                        canvasSize: proxy.size,
                        renderedSize: { placement in
                            CanvasPlacedText.boxSize(
                                of: selectedText.canvasText(placement: placement),
                                canvasSize: proxy.size
                            )
                        },
                        draft: draft,
                        onDeleteTap: { onTextDeleteTap(selectedText.id) }
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
                placedImage(topping, canvasSize: canvasSize)
                    .zIndex(topping.id == selectedToppingID ? Self.selectedZIndex : Double(order))
            }
        }
    }

    /// 내 사진·텍스트를 캔버스와 같은 `positionZ` 순서로 섞어 쌓는다.
    private func myLayerStack(canvasSize: CGSize) -> some View {
        let order = myLayerOrder
        return ZStack {
            ForEach(myToppings) { topping in
                placedImage(topping, canvasSize: canvasSize)
                    .zIndex(
                        topping.id == selectedToppingID
                            ? Self.selectedZIndex
                            : Double(order[.image(topping.id)] ?? 0)
                    )
            }
            ForEach(myTexts) { text in
                CanvasPlacedText(
                    canvasText: text.canvasText(placement: previewPlacement(of: text, in: canvasSize)),
                    canvasSize: canvasSize,
                    isSelected: text.id == selectedTextID
                )
                .zIndex(text.id == selectedTextID ? Self.selectedZIndex : Double(order[.text(text.id)] ?? 0))
            }
        }
    }

    private func placedImage(_ topping: CanvasEditStore.EditableTopping, canvasSize: CGSize) -> some View {
        CanvasPlacedImage(
            canvasImage: topping.canvasImage(placement: previewPlacement(of: topping, in: canvasSize)),
            canvasSize: canvasSize,
            isSelected: topping.id == selectedToppingID,
            onToppingLoaded: { toppingPixelSizes[topping.id] = $0 }
        )
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

    var myTexts: [CanvasEditStore.EditableText] {
        texts.filter(\.isMine)
    }

    var otherTexts: [CanvasEditStore.EditableText] {
        texts.filter { !$0.isMine }
    }

    var selectedText: CanvasEditStore.EditableText? {
        myTexts.first { $0.id == selectedTextID }
    }

    /// 내 사진·텍스트의 아래→위 순서. 이미지·텍스트 id 가 겹칠 수 있어 종류로 가른다.
    var myLayerOrder: [CanvasLayer.LayerID: Int] {
        let layers = myToppings.map { (CanvasLayer.LayerID.image($0.id), $0.positionZ) }
            + myTexts.map { (CanvasLayer.LayerID.text($0.id), $0.positionZ) }
        return Dictionary(
            uniqueKeysWithValues: layers
                .sorted { $0.1 < $1.1 }
                .enumerated()
                .map { ($0.element.0, $0.offset) }
        )
    }

    func previewPlacement(of text: CanvasEditStore.EditableText, in canvasSize: CGSize) -> ToppingPlacement {
        text.id == selectedTextID ? draft.applied(to: text.placement, in: canvasSize) : text.placement
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

    /// 선택된 것 → 내 것(위부터) → 남의 사진 → 남의 텍스트 순으로 탭을 받는다 — 그려지는 순서의 역순.
    func select(at point: CGPoint, in canvasSize: CGSize) {
        let isToppingTapped = { (topping: CanvasEditStore.EditableTopping) in
            topping.placement.contains(
                point,
                toppingPixelSize: toppingPixelSizes[topping.id] ?? .zero,
                canvasSize: canvasSize
            )
        }
        let isTextTapped = { (text: CanvasEditStore.EditableText) in
            text.placement.contains(
                point,
                renderedSize: CanvasPlacedText.boxSize(
                    of: text.canvasText(placement: text.placement),
                    canvasSize: canvasSize
                ),
                canvasSize: canvasSize
            )
        }

        if let selectedTopping, isToppingTapped(selectedTopping) {
            onToppingTap(selectedTopping.id)
            return
        }
        if let selectedText, isTextTapped(selectedText) {
            onTextTap(selectedText.id)
            return
        }

        let order = myLayerOrder
        let myTopmost = (
            myToppings.filter(isToppingTapped).map { CanvasLayer.LayerID.image($0.id) }
                + myTexts.filter(isTextTapped).map { CanvasLayer.LayerID.text($0.id) }
        )
        .max { (order[$0] ?? 0) < (order[$1] ?? 0) }

        switch myTopmost {
        case .image(let toppingID):
            onToppingTap(toppingID)
        case .text(let textID):
            onTextTap(textID)
        case nil:
            if let tappedTopping = otherToppings.last(where: isToppingTapped) {
                onToppingTap(tappedTopping.id)
            } else if let tappedText = otherTexts.last(where: isTextTapped) {
                onTextTap(tappedText.id)
            } else {
                onEmptyTap()
            }
        }
    }

    func commit(_ transform: ToppingTransformDraft, in canvasSize: CGSize) {
        if let selectedTopping {
            onPlacementChange(selectedTopping.id, transform.applied(to: selectedTopping.placement, in: canvasSize))
        } else if let selectedText {
            onTextPlacementChange(selectedText.id, transform.applied(to: selectedText.placement, in: canvasSize))
        }
    }
}
