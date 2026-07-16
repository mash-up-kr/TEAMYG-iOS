//
//  YGChip.swift
//  UIComponent
//
//  Created by 신상우 on 7/14/26.
//

import SwiftUI

/// 파르페 Chip 컴포넌트.
///
/// Figma `Button-Chip-Left`(아이콘 왼쪽) / `Button-Chip-Right`(아이콘 오른쪽) 를
/// 아이콘 위치(`placement`) 하나로 통합한다. 상태는 Default / Pressed 만 (Disabled 미지원).
public struct YGChip: View {
    /// 아이콘 위치 — `.leading`(Button-Chip-Left) / `.trailing`(Button-Chip-Right)
    public enum IconPlacement {
        case leading
        case trailing
    }

    private let title: String
    private let icon: Image
    private let placement: IconPlacement
    private let action: () -> Void

    public init(
        _ title: String,
        icon: Image,
        placement: IconPlacement,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.placement = placement
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: .gap2) {
                switch placement {
                case .leading:
                    iconView
                    titleView
                case .trailing:
                    titleView
                    iconView
                }
            }
        }
        .buttonStyle(YGChipStyle(placement: placement))
    }

    private var titleView: some View {
        Text(title)
            .suit(.body02Regular)
            .lineLimit(1)
    }

    private var iconView: some View {
        icon
            .renderingMode(.template)
            .resizable()
            .frame(width: 16, height: 16)
    }
}

private struct YGChipStyle: ButtonStyle {
    let placement: YGChip.IconPlacement

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground(isPressed: configuration.isPressed))
            .padding(.vertical, .padding2)
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .background(background(isPressed: configuration.isPressed), in: .capsule)
            .overlay {
                if showsBorder(isPressed: configuration.isPressed) {
                    Capsule().strokeBorder(.cherry100, lineWidth: 1)
                }
            }
    }

    /// 아이콘 쪽 padding-3(8) · 텍스트 쪽 padding-5(12)
    private var leadingPadding: CGFloat {
        placement == .leading ? .padding3 : .padding5
    }

    private var trailingPadding: CGFloat {
        placement == .leading ? .padding5 : .padding3
    }

    /// trailing(Right): default cherry100 → pressed cherry200
    /// leading(Left): default·pressed 모두 cherry50 (pressed 는 테두리로 구분)
    private func background(isPressed: Bool) -> Color {
        switch placement {
        case .trailing:
            return isPressed ? .cherry200 : .cherry100
        case .leading:
            return .cherry50
        }
    }

    private func showsBorder(isPressed: Bool) -> Bool {
        placement == .leading && isPressed
    }

    /// leading(Left): default gray600 → pressed gray700 (Figma Button-Chip-Left)
    /// trailing(Right): gray950 유지 (Button-Chip-Right 스펙 미확인)
    private func foreground(isPressed: Bool) -> Color {
        switch placement {
        case .leading:
            return isPressed ? .gray700 : .gray600
        case .trailing:
            return .gray950
        }
    }
}

#Preview {
    VStack(spacing: .gap5) {
        YGChip("새 그룹", icon: .icPlus, placement: .leading) {}
        YGChip("새 그룹", icon: .icPlus, placement: .trailing) {}
    }
    .padding()
}
