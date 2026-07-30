//
//  YGCircleButton.swift
//  UIComponent
//
//  Created by 김남수 on 7/30/26.
//

import SwiftUI

/// 파르페 원형 아이콘 버튼.
///
/// Figma `Button-Circle` — Type(Default·Secondary·Small) × Status(Default·Pressed).
/// 세 타입 모두 터치 영역은 44×44 로 같고, `.small` 만 보이는 원이 28×28 로 작다.
/// Figma 에 disabled 상태가 없어 색 분기도 두지 않았다 — `.disabled(true)` 는 탭만 막는다.
public struct YGCircleButton: View {
    public enum Variant {
        /// 원 44×44 · 아이콘 28×28 · 밝은 배경
        case `default`
        /// 원 44×44 · 아이콘 28×28 · 어두운 배경
        case secondary
        /// 원 28×28 · 아이콘 18×18 · 밝은 배경 (터치 영역은 44×44 유지)
        case small

        var circleLength: CGFloat { self == .small ? 28 : 44 }
        var iconLength: CGFloat { self == .small ? 18 : 28 }
    }

    private let icon: Image
    private let variant: Variant
    private let action: () -> Void

    public init(
        _ icon: Image,
        variant: Variant,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.variant = variant
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            icon
                .renderingMode(.template)
                .resizable()
                .frame(width: variant.iconLength, height: variant.iconLength)
        }
        .buttonStyle(YGCircleButtonStyle(variant: variant))
    }
}

private struct YGCircleButtonStyle: ButtonStyle {
    let variant: YGCircleButton.Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(iconColor)
            .frame(width: variant.circleLength, height: variant.circleLength)
            .background(backgroundColor(isPressed: configuration.isPressed), in: .circle)
            .overlay {
                Circle().strokeBorder(borderColor, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .frame(width: 44, height: 44)
            .contentShape(.rect)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .default, .small: return isPressed ? .gray100 : .whiteFixed
        case .secondary: return isPressed ? .gray950 : .gray900
        }
    }

    private var borderColor: Color {
        variant == .secondary ? .white25 : .black5
    }

    private var iconColor: Color {
        variant == .secondary ? .gray50 : .gray850
    }
}

#Preview {
    HStack(spacing: .gap5) {
        YGCircleButton(.icCaretLeft, variant: .default) {}
        YGCircleButton(.icPlus, variant: .secondary) {}
        YGCircleButton(.icReverse, variant: .small) {}
    }
    .padding(.padding8)
    .background(.gray200)
}
