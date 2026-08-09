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
                if placement == .leading {
                    Capsule().strokeBorder(.gray500, lineWidth: 1)
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

    /// leading(Left): default whiteFixed → pressed gray200, 보더는 gray500 고정
    ///   (2026-08 컨셉변경, Figma Button-Chip-Left Type=Default·Pressed).
    /// trailing(Right): default cherry100 → pressed cherry200 (구 컨셉, 새 스펙 미확인)
    private func background(isPressed: Bool) -> Color {
        switch placement {
        case .trailing:
            return isPressed ? .cherry200 : .cherry100
        case .leading:
            return isPressed ? .gray200 : .whiteFixed
        }
    }

    /// leading(Left): default gray900 → pressed gray950 (2026-08 컨셉변경)
    /// trailing(Right): gray950 유지 (Button-Chip-Right 스펙 미확인)
    private func foreground(isPressed: Bool) -> Color {
        switch placement {
        case .leading:
            return isPressed ? .gray950 : .gray900
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
