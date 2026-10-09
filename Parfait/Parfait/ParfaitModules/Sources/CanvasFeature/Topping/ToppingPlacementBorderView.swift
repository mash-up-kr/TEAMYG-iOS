//
//  ToppingPlacementBorderView.swift
//  CanvasFeature
//
//  Created by 박서연 on 10/9/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

struct ToppingPlacementBorderView: View {
    let canvasContent: CanvasStore.CanvasContent?
    let topping: ExtractedTopping
    let silhouette: CGImage?
    let border: ToppingBorder
    let editor: ToppingPlacementEditor
    let isBorderPanelExpanded: Bool
    let isSaving: Bool
    let onCanvasResize: (CGSize) -> Void
    let onTransform: (ToppingTransformDraft) -> Void
    let onBorderWidthChange: (Double) -> Void
    let onBorderColorSelect: (ToppingBorderColor) -> Void
    let onBorderPanelExpandTap: () -> Void
    let onBorderPanelClose: () -> Void
    let onBackTap: () -> Void
    let onCloseTap: () -> Void
    let onConfirmTap: () -> Void

    @State private var draft = ToppingTransformDraft()

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            canvas
                .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, .padding7)
                .padding(.top, .padding4)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(
                .backTitleClose("배치"),
                onBack: onBackTap,
                onClose: onCloseTap
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            YGButton("캔버스에 쌓기", variant: .large, action: onConfirmTap)
                .padding(.horizontal, .padding7)
                .padding(.vertical, .padding6)
        }
        .ygLoading(isSaving)
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

            ToppingTransformGestureOverlay(
                draft: $draft,
                placementCenter: editor.placement.center(in: editor.canvasSize),
                onTouchBegan: isBorderPanelExpanded ? onBorderPanelClose : nil,
                onCommit: onTransform
            )
        }
        .canvasBoardFrame()
        .overlay(alignment: .bottom) {
            borderPanel
        }
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: onCanvasResize)
    }

    private var placedTopping: some View {
        CanvasToppingLayer(
            topping: topping.image,
            silhouette: silhouette,
            borderColor: border.color.strokeColor,
            borderWidth: CGFloat(border.width),
            placement: draft.applied(to: editor.placement, in: editor.canvasSize),
            canvasSize: editor.canvasSize,
            isSelected: true
        )
    }

    @ViewBuilder
    private var borderPanel: some View {
        if isBorderPanelExpanded {
            ToppingBorderPanel(
                border: border,
                onWidthChange: onBorderWidthChange,
                onColorSelect: onBorderColorSelect,
                onCollapseTap: onBorderPanelClose
            )
        } else {
            ToppingBorderPanelHandle(onExpandTap: onBorderPanelExpandTap)
        }
    }
}
