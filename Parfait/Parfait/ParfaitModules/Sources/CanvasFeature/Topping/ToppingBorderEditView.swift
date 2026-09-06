//
//  ToppingBorderEditView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

struct ToppingBorderEditView: View {
    private static let historyBarInset: CGFloat = 18
    private static let chipLength: CGFloat = 36

    let topping: CGImage?
    let silhouette: CGImage?
    let border: ToppingBorder
    let canUndo: Bool
    let canRedo: Bool
    let onUndoTap: () -> Void
    let onRedoTap: () -> Void
    let onWidthChange: (Double) -> Void
    let onWidthEditingChange: (Bool) -> Void
    let onColorSelect: (ToppingBorderColor) -> Void
    let onPreviewLongEdgeChange: (CGFloat) -> Void
    let placementScale: Double?
    let showsAreaTab: Bool
    let singleTitle: String
    let onAreaTabTap: () -> Void
    let onCloseTap: () -> Void
    let onConfirmTap: () -> Void

    @State private var selectedTab = 1
    @State private var previewAreaSize: CGSize = .zero
    @State private var toppingMargin: CGSize = .zero

    init(
        topping: CGImage?,
        silhouette: CGImage?,
        border: ToppingBorder,
        canUndo: Bool,
        canRedo: Bool,
        onUndoTap: @escaping () -> Void,
        onRedoTap: @escaping () -> Void,
        onWidthChange: @escaping (Double) -> Void,
        onWidthEditingChange: @escaping (Bool) -> Void,
        onColorSelect: @escaping (ToppingBorderColor) -> Void,
        onPreviewLongEdgeChange: @escaping (CGFloat) -> Void,
        placementScale: Double?,
        showsAreaTab: Bool,
        singleTitle: String = "테두리",
        onAreaTabTap: @escaping () -> Void,
        onCloseTap: @escaping () -> Void,
        onConfirmTap: @escaping () -> Void
    ) {
        self.topping = topping
        self.silhouette = silhouette
        self.border = border
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.onUndoTap = onUndoTap
        self.onRedoTap = onRedoTap
        self.onWidthChange = onWidthChange
        self.onWidthEditingChange = onWidthEditingChange
        self.onColorSelect = onColorSelect
        self.onPreviewLongEdgeChange = onPreviewLongEdgeChange
        self.placementScale = placementScale
        self.showsAreaTab = showsAreaTab
        self.singleTitle = singleTitle
        self.onAreaTabTap = onAreaTabTap
        self.onCloseTap = onCloseTap
        self.onConfirmTap = onConfirmTap
    }

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: 0) {
                historyBar
                preview
                editArea
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            YGFloatingBar(
                showsAreaTab
                    ? .editTab(tabs: ["영역", "테두리"], selection: tabSelection)
                    : .edit(title: singleTitle),
                onClose: onCloseTap,
                onConfirm: onConfirmTap
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                guard newTab == 0 else {
                    selectedTab = newTab
                    return
                }
                onAreaTabTap()
            }
        )
    }

    private var historyBar: some View {
        ToppingHistoryBar(
            canUndo: canUndo,
            canRedo: canRedo,
            onUndoTap: onUndoTap,
            onRedoTap: onRedoTap
        )
        .padding(.horizontal, Self.historyBarInset)
        .padding(.top, .padding3)
    }

    private var preview: some View {
        ZStack {
            if let topping {
                ToppingBorderedImage(
                    topping: topping,
                    silhouette: silhouette,
                    borderColor: border.color.strokeColor,
                    borderWidth: previewBorderWidth,
                    size: fittedToppingSize
                )
            } else {
                ProgressView()
                    .tint(.gray500)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { previewAreaSize = $0 }
        .task(id: topping.map(ObjectIdentifier.init)) {
            toppingMargin = await Self.opaqueMargin(of: topping)
        }
        .onChange(of: placedLongSide, initial: true) { _, longSide in
            onPreviewLongEdgeChange(longSide)
        }
        .padding(.horizontal, .padding7)
        .padding(.vertical, .padding6)
    }

    private var toppingPixelSize: CGSize {
        guard let topping, topping.width > 0, topping.height > 0 else { return .zero }
        return CGSize(width: topping.width, height: topping.height)
    }

    private var placedLongSide: CGFloat {
        let pixelSize = toppingPixelSize
        guard pixelSize.width > 0, previewAreaSize.width > 0 else { return 0 }

        let canvasSize = CGSize(
            width: previewAreaSize.width,
            height: previewAreaSize.width / CanvasArea.aspectRatio
        )
        let scale = placementScale
            ?? ToppingPlacement.initial(toppingPixelSize: pixelSize, canvasSize: canvasSize).scale

        return ToppingPlacement(scale: scale).longSide(in: canvasSize)
    }

    private var previewZoom: CGFloat {
        let previewLongSide = max(fittedToppingSize.width, fittedToppingSize.height)
        guard placedLongSide > 0, previewLongSide > 0 else { return 1 }

        return previewLongSide / placedLongSide
    }

    private var previewBorderWidth: CGFloat {
        CGFloat(border.width) * previewZoom
    }

    private var fittedToppingSize: CGSize {
        let pixelSize = toppingPixelSize
        guard pixelSize.width > 0, previewAreaSize.width > 0, previewAreaSize.height > 0
        else { return .zero }

        let aspectFit = min(previewAreaSize.width / pixelSize.width, previewAreaSize.height / pixelSize.height)
        let scale = border.isVisible
            ? min(aspectFit, maximumScaleFittingBorder(pixelSize: pixelSize))
            : aspectFit

        return CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)
    }

    private func maximumScaleFittingBorder(pixelSize: CGSize) -> CGFloat {
        let objectHalfWidth = pixelSize.width / 2 - toppingMargin.width
        let objectHalfHeight = pixelSize.height / 2 - toppingMargin.height
        guard objectHalfWidth > 0, objectHalfHeight > 0, placedLongSide > 0
        else { return .greatestFiniteMagnitude }

        let borderPixels = CGFloat(border.width) * max(pixelSize.width, pixelSize.height) / placedLongSide

        return min(
            previewAreaSize.width / 2 / (objectHalfWidth + borderPixels),
            previewAreaSize.height / 2 / (objectHalfHeight + borderPixels)
        )
    }

    private static func opaqueMargin(of image: CGImage?) async -> CGSize {
        guard let image else { return .zero }

        return await Task.detached(priority: .userInitiated) {
            guard let bounds = image.opaqueBounds() else { return .zero }
            return CGSize(
                width: min(bounds.minX, CGFloat(image.width) - bounds.maxX),
                height: min(bounds.minY, CGFloat(image.height) - bounds.maxY)
            )
        }.value
    }

    private var editArea: some View {
        VStack(alignment: .leading, spacing: .gap3) {
            Text("테두리 굵기")
                .suit(.caption01Medium)
                .foregroundStyle(.gray800)
                .padding(.horizontal, .padding7)

            YGSlider(
                value: Binding(get: { border.width }, set: { onWidthChange($0) }),
                in: ToppingBorder.widthRange,
                onEditingChanged: onWidthEditingChange
            )
            .padding(.horizontal, .padding7)

            palette
        }
        .padding(.bottom, .padding6)
    }

    private var palette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .gap3) {
                ForEach(ToppingBorderColor.allCases) { color in
                    paletteChip(color)
                }
            }
            .padding(.horizontal, .padding7)
            .padding(.vertical, .padding2)
        }
    }

    private func paletteChip(_ color: ToppingBorderColor) -> some View {
        Button {
            onColorSelect(color)
        } label: {
            Circle()
                .fill(color.chipColor)
                .frame(width: Self.chipLength, height: Self.chipLength)
                .overlay {
                    Circle()
                        .strokeBorder(chipOutlineColor(for: color), lineWidth: 1)
                }
                .overlay {
                    if color == .none {
                        chipSlash(isSelected: color == border.color)
                    }
                }
                .overlay {
                    if color == border.color, color != .none {
                        Circle()
                            .fill(.black25)
                            .overlay {
                                Image.icCheck
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.whiteFixed)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func chipOutlineColor(for color: ToppingBorderColor) -> Color {
        color == .none && color == border.color ? .gray850 : .black5
    }

    private func chipSlash(isSelected: Bool) -> some View {
        Path { path in
            path.move(to: CGPoint(x: Self.chipLength * 0.15, y: Self.chipLength * 0.85))
            path.addLine(to: CGPoint(x: Self.chipLength * 0.85, y: Self.chipLength * 0.15))
        }
        .stroke(isSelected ? Color.gray850 : .gray100, lineWidth: 1)
    }
}
