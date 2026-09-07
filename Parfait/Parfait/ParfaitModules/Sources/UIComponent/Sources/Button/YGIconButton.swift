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

    /// 아이콘 색. Figma 는 `Button-Icon` 껍데기는 그대로 두고 안의 아이콘 색만 자리마다 덮어 쓴다.
    public enum Tone {
        /// gray300 → pressed gray400. 상단 바 등 기본값.
        case normal
        /// gray800 → pressed gray900. 캔버스 날짜 바 저장 버튼처럼 강조되는 자리.
        case strong
    }

    private let icon: Image
    private let size: Size
    private let tone: Tone
    private let action: () -> Void

    public init(
        _ icon: Image,
        size: Size,
        tone: Tone = .normal,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.tone = tone
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            icon
                .renderingMode(.template)
                .resizable()
                .frame(width: size.iconLength, height: size.iconLength)
        }
        .buttonStyle(YGIconButtonStyle(size: size, tone: tone))
    }
}

private struct YGIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let size: YGIconButton.Size
    let tone: YGIconButton.Tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(iconColor(isPressed: configuration.isPressed))
            .frame(width: size.touchLength, height: size.touchLength)
            .contentShape(.rect)
    }

    /// disabled 는 톤과 무관하게 gray200.
    private func iconColor(isPressed: Bool) -> Color {
        guard isEnabled else { return .gray200 }
        switch tone {
        case .normal: return isPressed ? .gray400 : .gray300
        case .strong: return isPressed ? .gray900 : .gray800
        }
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
        HStack(spacing: .gap5) {
            YGIconButton(.icSave, size: .small, tone: .strong) {}
            YGIconButton(.icSave, size: .small, tone: .strong) {}
                .disabled(true)
        }
    }
    .padding()
}
