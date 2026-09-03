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
    private static let handleLength: CGFloat = 44
    private static let handleCircleLength: CGFloat = 28
    private static let handleIconLength: CGFloat = 18
    private static let handleCornerOffset: CGFloat = 22

    let canvasContent: CanvasStore.CanvasContent?
    let topping: ExtractedTopping
    let silhouette: CGImage?
    let borderColor: Color?
    let editor: ToppingPlacementEditor
    let onCanvasResize: (CGSize) -> Void
    let onMove: (CGSize) -> Void
    let onScale: (Double) -> Void
    let onRotate: (Double) -> Void
    let onCloseTap: () -> Void
    let onConfirmTap: () -> Void

    @State private var dragTranslation: CGSize = .zero
    @State private var scaleFactor: Double = 1
    @State private var rotationDelta: Double = 0

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
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            YGFloatingBar(
                .edit(title: "토핑 배치"),
                onClose: onCloseTap,
                onConfirm: onConfirmTap
            )
        }
    }

    private var canvas: some View {
        ZStack {
            Color.whiteFixed

            if let canvasContent {
                CanvasContentView(content: canvasContent)
            }

            Color.gray500

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
        icon
            .renderingMode(.template)
            .resizable()
            .frame(width: Self.handleIconLength, height: Self.handleIconLength)
            .foregroundStyle(.gray900)
            .frame(width: Self.handleCircleLength, height: Self.handleCircleLength)
            .background(.whiteFixed, in: .circle)
            .overlay {
                Circle()
                    .strokeBorder(.black5, lineWidth: 1)
            }
            .frame(width: Self.handleLength, height: Self.handleLength)
            .contentShape(.rect)
            .gesture(gesture)
    }
}

private extension ToppingPlacementView {
    var previewPlacement: ToppingPlacement {
        editor.magnifying(by: scaleFactor)
            .moved(by: dragTranslation, in: editor.canvasSize)
            .rotated(by: rotationDelta)
    }

    var previewCenter: CGPoint {
        previewPlacement.center(in: editor.canvasSize)
    }

    var renderedSize: CGSize {
        previewPlacement.renderedSize(toppingPixelSize: topping.pixelSize, canvasSize: editor.canvasSize)
    }

    /// 핸들은 회전한 토핑의 오른쪽 두 모서리 바깥에 붙는다 (Figma `C-106`).
    func handleCenter(towardBottom: Bool) -> CGPoint {
        let halfWidth = renderedSize.width / 2 + Self.handleCornerOffset
        let halfHeight = renderedSize.height / 2 + Self.handleCornerOffset
        let corner = CGSize(width: halfWidth, height: towardBottom ? halfHeight : -halfHeight)
        let radians = previewPlacement.rotationDegrees * .pi / 180
        let center = previewCenter

        return CGPoint(
            x: center.x + corner.width * cos(radians) - corner.height * sin(radians),
            y: center.y + corner.width * sin(radians) + corner.height * cos(radians)
        )
    }

    var moveGesture: some Gesture {
        DragGesture(coordinateSpace: .named(Self.canvasSpace))
            .onChanged { value in
                dragTranslation = value.translation
            }
            .onEnded { value in
                dragTranslation = .zero
                onMove(value.translation)
            }
    }

    var scaleGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.canvasSpace))
            .onChanged { value in
                scaleFactor = magnification(for: value)
            }
            .onEnded { value in
                let factor = magnification(for: value)
                scaleFactor = 1
                onScale(factor)
            }
    }

    var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.canvasSpace))
            .onChanged { value in
                rotationDelta = rotation(for: value)
            }
            .onEnded { value in
                let degrees = rotation(for: value)
                rotationDelta = 0
                onRotate(degrees)
            }
    }

    func magnification(for value: DragGesture.Value) -> Double {
        let center = editor.center
        let startDistance = hypot(value.startLocation.x - center.x, value.startLocation.y - center.y)
        let currentDistance = hypot(value.location.x - center.x, value.location.y - center.y)
        guard startDistance > 0 else { return 1 }

        return Double(currentDistance / startDistance)
    }

    func rotation(for value: DragGesture.Value) -> Double {
        let center = editor.center
        let startAngle = atan2(value.startLocation.y - center.y, value.startLocation.x - center.x)
        let currentAngle = atan2(value.location.y - center.y, value.location.x - center.x)
        let degrees = Angle(radians: Double(currentAngle - startAngle)).degrees

        return remainder(degrees, 360)
    }
}
