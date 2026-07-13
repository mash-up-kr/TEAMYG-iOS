//
//  YGIconButton.swift
//  UIComponent
//
//  Created by 김남수 on 7/12/26.
//

import SwiftUI

/// 상태(default·pressed·disabled)에 따라 아이콘 색상이 바뀐다.
public struct YGIconButton: View {
    public enum Size {
        /// 아이콘 24×24 · 터치 영역 44×44
        case small
        /// 아이콘 32×32 · 터치 영역 48×48
        case large

        var iconLength: CGFloat {
            switch self {
            case .small: return 24
            case .large: return 32
            }
        }

        var touchLength: CGFloat {
            switch self {
            case .small: return 44
            case .large: return 48
            }
        }
    }

    private let icon: Image
    private let size: Size
    private let action: () -> Void

    public init(
        _ icon: Image,
        size: Size,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            icon
                .renderingMode(.template)
                .resizable()
                .frame(width: size.iconLength, height: size.iconLength)
        }
        .buttonStyle(YGIconButtonStyle(size: size))
    }
}

private struct YGIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let size: YGIconButton.Size

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(iconColor(isPressed: configuration.isPressed))
            .frame(width: size.touchLength, height: size.touchLength)
            .contentShape(.rect)
    }

    /// default → gray300 · pressed → gray400 · disabled → gray200
    private func iconColor(isPressed: Bool) -> Color {
        guard isEnabled else { return .gray200 }
        return isPressed ? .gray400 : .gray300
    }
}

#Preview {
    VStack(spacing: .gap5) {
        HStack(spacing: .gap5) {
            YGIconButton(.icClose, size: .small) {}
            YGIconButton(.icHamburger, size: .small) {}
            YGIconButton(.icHamburger, size: .small) {}
                .disabled(true)
        }
        HStack(spacing: .gap5) {
            YGIconButton(.icClose, size: .large) {}
            YGIconButton(.icHamburger, size: .large) {}
            YGIconButton(.icHamburger, size: .large) {}
                .disabled(true)
        }
    }
    .padding()
}
