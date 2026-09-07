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

    let canvasContent: CanvasStore.CanvasContent?
    let topping: ExtractedTopping
    let silhouette: CGImage?
    let borderColor: Color?
    let borderWidth: CGFloat
    let editor: ToppingPlacementEditor
    let isSaving: Bool
    let onCanvasResize: (CGSize) -> Void
    let onTransform: (ToppingTransformDraft) -> Void
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

            transformGestureOverlay
        }
        .canvasBoardFrame()
        .overlay {
            ToppingEditHandles(
                placement: editor.placement,
                canvasSize: editor.canvasSize,
                toppingPixelSize: topping.pixelSize,
                coordinateSpace: Self.canvasSpace,
                draft: $draft,
                onCommit: onTransform
            )
        }
        .coordinateSpace(.named(Self.canvasSpace))
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: onCanvasResize)
    }

    private var placedTopping: some View {
        CanvasToppingLayer(
            topping: topping.image,
            silhouette: silhouette,
            borderColor: borderColor,
            borderWidth: borderWidth,
            placement: previewPlacement,
            canvasSize: editor.canvasSize,
            isSelected: true
        )
    }
}

private extension ToppingPlacementView {
    var previewPlacement: ToppingPlacement {
        draft.applied(to: editor.placement, in: editor.canvasSize)
    }

    /// 배치 화면은 토핑이 하나뿐이라 캔버스 전체를 제스처 면으로 쓴다 —
    /// 두 번째 손가락이 토핑 밖에 닿아도 핀치가 잡힌다.
    var transformGestureOverlay: some View {
        ToppingTransformGestureOverlay(draft: $draft, onCommit: onTransform)
    }
}
