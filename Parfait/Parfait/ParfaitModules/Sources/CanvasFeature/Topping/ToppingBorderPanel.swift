//
//  ToppingBorderPanel.swift
//  CanvasFeature
//
//  Created by 박서연 on 10/9/26.
//

import SwiftUI
import UIComponent

struct ToppingBorderPanel: View {
    private static let chipLength: CGFloat = 36
    private static let caretLength: CGFloat = 24

    let border: ToppingBorder
    let onWidthChange: (Double) -> Void
    let onColorSelect: (ToppingBorderColor) -> Void
    let onCollapseTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .gap3) {
            HStack(spacing: 0) {
                Text("테두리 굵기")
                    .suit(.caption01Medium)
                    .foregroundStyle(.gray700)

                Spacer(minLength: 0)

                Button(action: onCollapseTap) {
                    Image.icCaretBottom
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: Self.caretLength, height: Self.caretLength)
                        .foregroundStyle(.gray800)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, .padding6)

            YGSlider(
                value: Binding(get: { border.width }, set: { onWidthChange($0) }),
                in: ToppingBorder.widthRange
            )
            .frame(height: 32)
            .padding(.horizontal, .padding6)

            palette
        }
        .padding(.vertical, .padding7)
        .background(.whiteFixed)
    }

    private var palette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .gap3) {
                ForEach(ToppingBorderColor.allCases) { color in
                    paletteChip(color)
                }
            }
            .padding(.horizontal, .padding6)
            .padding(.top, .padding2)
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

struct ToppingBorderPanelHandle: View {
    private static let caretLength: CGFloat = 24

    let onExpandTap: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: onExpandTap) {
            HStack(spacing: 0) {
                Text("테두리 설정")
                    .suit(.caption01Medium)
                    .foregroundStyle(isEnabled ? .gray700 : .gray400)

                Spacer(minLength: 0)

                Image.icCaretTop
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: Self.caretLength, height: Self.caretLength)
                    .foregroundStyle(isEnabled ? .gray800 : .gray400)
            }
            .padding(.padding6)
            .background(.white75)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
