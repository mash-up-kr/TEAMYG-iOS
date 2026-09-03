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
    private static let historyButtonLength: CGFloat = 42
    private static let chipLength: CGFloat = 36

    let topping: ExtractedTopping
    let silhouette: CGImage?
    let border: ToppingBorder
    let canUndo: Bool
    let canRedo: Bool
    let onUndoTap: () -> Void
    let onRedoTap: () -> Void
    let onWidthChange: (Double) -> Void
    let onWidthEditingChange: (Bool) -> Void
    let onColorSelect: (ToppingBorderColor) -> Void
    let onAreaTabTap: () -> Void
    let onCloseTap: () -> Void
    let onConfirmTap: () -> Void

    @State private var selectedTab = 1

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
                .editTab(tabs: ["영역", "테두리"], selection: tabSelection),
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
        HStack(spacing: .gap3) {
            historyButton(.icArrowLeft, isEnabled: canUndo, action: onUndoTap)
            historyButton(.icArrowRight, isEnabled: canRedo, action: onRedoTap)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, .padding3)
    }

    private func historyButton(_ icon: Image, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(isEnabled ? Color.gray900 : .gray300)
                .frame(width: Self.historyButtonLength, height: Self.historyButtonLength)
                .background(.gray100, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var preview: some View {
        ZStack {
            if let silhouette, let strokeColor = border.color.strokeColor {
                Image(decorative: silhouette, scale: 1, orientation: .up)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(strokeColor)
                    .scaledToFit()
            }

            Image(decorative: topping.image, scale: 1, orientation: .up)
                .resizable()
                .scaledToFit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, .padding7)
        .padding(.vertical, .padding6)
    }

    private var editArea: some View {
        VStack(alignment: .leading, spacing: .gap3) {
            Text("테두리 굵기")
                .suit(.caption01Medium)
                .foregroundStyle(.gray800)

            YGSlider(
                value: Binding(get: { border.width }, set: { onWidthChange($0) }),
                in: ToppingBorder.widthRange,
                onEditingChanged: onWidthEditingChange
            )

            palette
        }
        .padding(.horizontal, .padding7)
        .padding(.bottom, .padding6)
    }

    private var palette: some View {
        HStack(spacing: 0) {
            ForEach(ToppingBorderColor.allCases) { color in
                paletteChip(color)
                    .frame(maxWidth: .infinity)
            }
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
                    if color.needsChipOutline {
                        Circle().strokeBorder(.gray300, lineWidth: 1)
                    }
                }
                .overlay {
                    if color == .none {
                        chipSlash
                    }
                }
                .overlay {
                    if color == border.color {
                        Circle()
                            .fill(.black50)
                            .overlay {
                                Image.icCheck
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(.whiteFixed)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var chipSlash: some View {
        Path { path in
            path.move(to: CGPoint(x: Self.chipLength * 0.24, y: Self.chipLength * 0.76))
            path.addLine(to: CGPoint(x: Self.chipLength * 0.76, y: Self.chipLength * 0.24))
        }
        .stroke(.gray500, lineWidth: 1)
    }
}
