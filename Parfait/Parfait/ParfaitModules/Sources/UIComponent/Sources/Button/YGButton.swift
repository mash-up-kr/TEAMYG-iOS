//
//  YGButton.swift
//  UIComponent
//
//  Created by 김남수 on 7/8/26.
//

import SwiftUI

public struct YGButton: View {
    public enum Variant {
        /// 높이 48 · 가로 유동(가용 폭 채움) · 좌우 패딩 20 · 사각 배경
        case large
        /// 136×48 고정
        case mediumPrimary
        /// 136×48 고정
        case mediumSecondary
        /// 136×48 고정 · 반투명 배경
        case mediumTransparency
        /// 내용 크기 · 좌우 12 · 상하 10 (Figma `Button-SmallSquare`)
        case smallSquare
    }

    private let title: String
    private let variant: Variant
    private let fillsWidth: Bool
    private let action: () -> Void

    /// - Parameter fillsWidth: `true` 면 medium 계열도 고정폭(136) 대신 가용 폭을 채운다. `smallSquare` 는 무시.
    public init(
        _ title: String,
        variant: Variant,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.fillsWidth = fillsWidth
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(YGButtonStyle(variant: variant, fillsWidth: variant == .large || fillsWidth))
    }
}

private struct YGButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let variant: YGButton.Variant
    let fillsWidth: Bool

    func makeBody(configuration: Configuration) -> some View {
        sized(configuration.label.foregroundStyle(textColor))
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: .rect
            )
            .overlay {
                if variant == .mediumSecondary {
                    Rectangle()
                        .strokeBorder(isEnabled ? Color.gray500 : .gray300, lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }

    @ViewBuilder
    private func sized(_ label: some View) -> some View {
        if variant == .smallSquare {
            label
                .suit(.body02SemiBold)
                .padding(.horizontal, .padding5)
                .padding(.vertical, .padding4)
        } else {
            label
                .suit(.body01SemiBold)
                .padding(.horizontal, .padding7)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(width: fillsWidth ? nil : 136, height: 48)
        }
    }

    private var textColor: Color {
        guard isEnabled else { return variant == .smallSquare ? .gray400 : .gray500 }
        switch variant {
        case .large, .mediumPrimary, .smallSquare: return .whiteFixed
        case .mediumSecondary, .mediumTransparency: return .gray900
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .large, .mediumPrimary:
            guard isEnabled else { return .gray200 }
            return isPressed ? .gray950 : .gray900
        case .smallSquare:
            guard isEnabled else { return .gray200 }
            return isPressed ? .blackFixed : .gray900
        case .mediumSecondary:
            guard isEnabled else { return .gray200 }
            return isPressed ? .gray200 : .gray100
        case .mediumTransparency:
            guard isEnabled else { return .whiteFixed.opacity(0.5) }
            return isPressed ? .whiteFixed.opacity(0.9) : .whiteFixed.opacity(0.5)
        }
    }
}

#Preview {
    VStack(spacing: .gap5) {
        YGButton("Large", variant: .large) {}
        YGButton("Large Disabled", variant: .large) {}
            .disabled(true)
        YGButton("Primary", variant: .mediumPrimary) {}
        YGButton("Primary Disabled", variant: .mediumPrimary) {}
            .disabled(true)
        YGButton("Secondary", variant: .mediumSecondary) {}
        YGButton("Secondary Disabled", variant: .mediumSecondary) {}
            .disabled(true)
        YGButton("Transparency", variant: .mediumTransparency) {}
        YGButton("Transparency Disabled", variant: .mediumTransparency) {}
            .disabled(true)
        YGButton("SmallSquare", variant: .smallSquare) {}
        YGButton("SmallSquare Disabled", variant: .smallSquare) {}
            .disabled(true)
    }
    .padding()
    .background(.orange) // Transparency 반투명 확인용
}
