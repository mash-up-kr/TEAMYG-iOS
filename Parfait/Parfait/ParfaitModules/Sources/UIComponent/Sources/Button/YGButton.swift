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
    }

    private let title: String
    private let variant: Variant
    private let action: () -> Void

    public init(
        _ title: String,
        variant: Variant,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(YGButtonStyle(variant: variant))
    }
}

private struct YGButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let variant: YGButton.Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .suit(.body01SemiBold)
            .foregroundStyle(textColor)
            .padding(.horizontal, .padding7)
            .frame(maxWidth: variant == .large ? .infinity : nil)
            .frame(width: variant == .large ? nil : 136, height: 48)
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

    private var textColor: Color {
        guard isEnabled else { return .gray500 }
        switch variant {
        case .large, .mediumPrimary: return .whiteFixed
        case .mediumSecondary, .mediumTransparency: return .gray900
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .large, .mediumPrimary:
            guard isEnabled else { return .gray200 }
            return isPressed ? .gray950 : .gray900
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
    }
    .padding()
    .background(.orange) // Transparency 반투명 확인용
}
