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
        .clipped()
        .overlay {
            Rectangle()
                .strokeBorder(.gray500, lineWidth: 1)
                .allowsHitTesting(false)
        }
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
                handles
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

    private var handles: some View {
        ZStack {
            actionHandle(.icClose, action: onDeleteTap)
                .position(handleCenter(horizontal: -1, vertical: -1))

            gestureHandle(.icRotate, gesture: rotateGesture)
                .position(handleCenter(horizontal: 1, vertical: -1))

            actionHandle(.icEdit, action: onBorderEditTap)
                .position(handleCenter(horizontal: -1, vertical: 1))

            gestureHandle(.icScale, gesture: scaleGesture)
                .position(handleCenter(horizontal: 1, vertical: 1))
        }
    }

    private func actionHandle(_ icon: Image, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ToppingHandleIcon(icon)
        }
        .buttonStyle(.plain)
    }

    private func gestureHandle(_ icon: Image, gesture: some Gesture) -> some View {
        ToppingHandleIcon(icon)
            .gesture(gesture)
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

    func handleCenter(horizontal: CGFloat, vertical: CGFloat) -> CGPoint {
        previewPlacement.handleCenter(
            horizontal: horizontal,
            vertical: vertical,
            frameSize: ToppingSelectionFrame.size(around: renderedSize),
            cornerOffset: ToppingHandle.cornerOffset,
            in: canvasSize
        )
    }

    func commit(_ transform: ToppingTransformDraft) {
        onPlacementChange(transform.applied(to: topping.placement, in: canvasSize))
    }

    var scaleGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace))
            .onChanged { draft.scaleByHandle(magnification: magnification(for: $0)) }
            .onEnded { _ in commit(draft.endTransform()) }
    }

    var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace))
            .onChanged { draft.rotateByHandle(rawDegrees: rotation(for: $0)) }
            .onEnded { _ in commit(draft.endTransform()) }
    }

    func magnification(for value: DragGesture.Value) -> Double {
        topping.placement.magnification(from: value.startLocation, to: value.location, in: canvasSize)
    }

    func rotation(for value: DragGesture.Value) -> Double {
        topping.placement.rotation(from: value.startLocation, to: value.location, in: canvasSize)
    }
}
