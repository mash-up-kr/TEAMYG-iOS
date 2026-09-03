//
//  ToppingPlacementView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

struct ToppingPlacementView: View {
    private static let canvasTopSpacing: CGFloat = 60
    private static let canvasSpace = "ToppingPlacementCanvas"
    private static let selectionStrokeWidth: CGFloat = 2

    let canvasContent: CanvasStore.CanvasContent?
    let topping: ExtractedTopping
    let silhouette: CGImage?
    let borderColor: Color?
    let editor: ToppingPlacementEditor
    let isSaving: Bool
    let onCanvasResize: (CGSize) -> Void
    let onMove: (CGSize) -> Void
    let onScale: (Double) -> Void
    let onRotate: (Double) -> Void
    let onCloseTap: () -> Void
    let onConfirmTap: () -> Void

    @State private var draft = ToppingTransformDraft()

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: 0) {
                canvas
                    .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, .padding7)
            .padding(.top, Self.canvasTopSpacing)

            if isSaving {
                Color.black25
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.whiteFixed)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            YGFloatingBar(
                .edit(title: "토핑 배치"),
                onClose: onCloseTap,
                onConfirm: onConfirmTap
            )
        }
        .disabled(isSaving)
    }

    private var canvas: some View {
        ZStack {
            Color.whiteFixed

            if let canvasContent {
                CanvasContentView(content: canvasContent)
            }

            Color.black25

            placedTopping
        }
        .clipShape(.rect)
        .overlay {
            Rectangle()
                .stroke(Color.gray500, lineWidth: 1)
        }
        .overlay {
            handles
        }
        .coordinateSpace(.named(Self.canvasSpace))
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: onCanvasResize)
    }

    private var placedTopping: some View {
        ZStack {
            if let silhouette, let borderColor {
                Image(decorative: silhouette, scale: 1, orientation: .up)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(borderColor)
            }

            Image(decorative: topping.image, scale: 1, orientation: .up)
                .resizable()
        }
        .frame(width: renderedSize.width, height: renderedSize.height)
        .overlay {
            Rectangle()
                .strokeBorder(Color.whiteFixed, lineWidth: Self.selectionStrokeWidth)
        }
        .rotationEffect(.degrees(previewPlacement.rotationDegrees))
        .position(previewCenter)
        .gesture(moveGesture)
    }

    private var handles: some View {
        ZStack {
            handle(.icScale, gesture: scaleGesture)
                .position(handleCenter(towardBottom: false))

            handle(.icRotate, gesture: rotateGesture)
                .position(handleCenter(towardBottom: true))
        }
    }

    private func handle(_ icon: Image, gesture: some Gesture) -> some View {
        ToppingHandleIcon(icon)
            .gesture(gesture)
    }
}

private extension ToppingPlacementView {
    var previewPlacement: ToppingPlacement {
        draft.applied(to: editor.placement, in: editor.canvasSize)
    }

    var previewCenter: CGPoint {
        previewPlacement.center(in: editor.canvasSize)
    }

    var renderedSize: CGSize {
        previewPlacement.renderedSize(toppingPixelSize: topping.pixelSize, canvasSize: editor.canvasSize)
    }

    /// 핸들은 회전한 토핑의 오른쪽 두 모서리 바깥에 붙는다 (Figma `C-106`).
    func handleCenter(towardBottom: Bool) -> CGPoint {
        previewPlacement.handleCenter(
            horizontal: 1,
            vertical: towardBottom ? 1 : -1,
            renderedSize: renderedSize,
            cornerOffset: ToppingHandle.cornerOffset,
            in: editor.canvasSize
        )
    }

    var moveGesture: some Gesture {
        DragGesture(coordinateSpace: .named(Self.canvasSpace))
            .onChanged { draft.translation = $0.translation }
            .onEnded { value in
                draft.reset()
                onMove(value.translation)
            }
    }

    var scaleGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.canvasSpace))
            .onChanged { draft.scaleFactor = magnification(for: $0) }
            .onEnded { value in
                let factor = magnification(for: value)
                draft.reset()
                onScale(factor)
            }
    }

    var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.canvasSpace))
            .onChanged { draft.accumulateRotation(rawDegrees: rotation(for: $0)) }
            .onEnded { value in
                draft.accumulateRotation(rawDegrees: rotation(for: value))
                let degrees = draft.rotationDegrees
                draft.reset()
                onRotate(degrees)
            }
    }

    func magnification(for value: DragGesture.Value) -> Double {
        editor.placement.magnification(
            from: value.startLocation,
            to: value.location,
            in: editor.canvasSize
        )
    }

    func rotation(for value: DragGesture.Value) -> Double {
        editor.placement.rotation(
            from: value.startLocation,
            to: value.location,
            in: editor.canvasSize
        )
    }
}
