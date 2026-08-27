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

                ForEach(toppings.filter(\.isMine)) { topping in
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
                    .zIndex(topping.id == selectedToppingID ? 10_000 : 1_000 + topping.positionZ)
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
    @State private var dragTranslation: CGSize = .zero
    @State private var scaleFactor: Double = 1
    @State private var rotationDelta: Double = 0

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
        Color.clear
            .frame(width: renderedSize.width, height: renderedSize.height)
            .contentShape(.rect)
            .rotationEffect(.degrees(previewPlacement.rotationDegrees))
            .position(center)
            .onTapGesture(perform: onTap)
            .gesture(moveGesture, isEnabled: isSelected)
    }

    private var handles: some View {
        ZStack {
            actionHandle(.icClose, action: onDeleteTap)
                .position(handleCenter(horizontal: -1, vertical: -1))

            gestureHandle(.icScale, gesture: scaleGesture)
                .position(handleCenter(horizontal: 1, vertical: -1))

            actionHandle(.icEdit, action: onBorderEditTap)
                .position(handleCenter(horizontal: -1, vertical: 1))

            gestureHandle(.icRotate, gesture: rotateGesture)
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
        topping.placement
            .magnified(by: scaleFactor)
            .moved(by: dragTranslation, in: canvasSize)
            .rotated(by: rotationDelta)
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
            renderedSize: renderedSize,
            cornerOffset: ToppingHandle.cornerOffset,
            in: canvasSize
        )
    }

    var moveGesture: some Gesture {
        DragGesture(coordinateSpace: .named(coordinateSpace))
            .onChanged { dragTranslation = $0.translation }
            .onEnded { value in
                onPlacementChange(topping.placement.moved(by: value.translation, in: canvasSize))
                dragTranslation = .zero
            }
    }

    var scaleGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace))
            .onChanged { scaleFactor = magnification(for: $0) }
            .onEnded { value in
                onPlacementChange(topping.placement.magnified(by: magnification(for: value)))
                scaleFactor = 1
            }
    }

    var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace))
            .onChanged { rotationDelta = rotation(for: $0) }
            .onEnded { value in
                onPlacementChange(topping.placement.rotated(by: rotation(for: value)))
                rotationDelta = 0
            }
    }

    func magnification(for value: DragGesture.Value) -> Double {
        topping.placement.magnification(from: value.startLocation, to: value.location, in: canvasSize)
    }

    func rotation(for value: DragGesture.Value) -> Double {
        topping.placement.rotation(from: value.startLocation, to: value.location, in: canvasSize)
    }
}
