//
//  CanvasMenu.swift
//  CanvasFeature
//
//  Created by 박서연 on 7/30/26.
//

import SwiftUI
import UIComponent

struct CanvasMenuBar: View {
    let onToppingAddTap: () -> Void
    let onCanvasEditTap: () -> Void

    var body: some View {
        HStack(spacing: -1) {
            CanvasMenuButton(
                "토핑 추가",
                icon: .icPlus,
                style: .primary,
                action: onToppingAddTap
            )
            CanvasMenuButton(
                "캔버스 편집",
                icon: .icCaretRight,
                style: .primary,
                action: onCanvasEditTap
            )
        }
    }
}

struct CanvasMenuSourceOptions: View {
    let onCameraOptionTap: () -> Void
    let onGalleryOptionTap: () -> Void

    var body: some View {
        VStack(spacing: -1) {
            CanvasMenuButton("카메라로 촬영", style: .option, action: onCameraOptionTap)
            CanvasMenuButton("갤러리에서 선택", style: .option, action: onGalleryOptionTap)
        }
    }
}

private struct CanvasMenuButton: View {
    enum Style {
        case primary
        case option
    }

    let title: String
    let icon: Image?
    let style: Style
    let action: () -> Void

    init(
        _ title: String,
        icon: Image? = nil,
        style: Style,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: .gap1) {
                Text(title)

                if let icon {
                    icon
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }
            .suit(.body02Regular)
            .foregroundStyle(.gray700)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(CanvasMenuButtonStyle(style: style))
    }
}

private struct CanvasMenuButtonStyle: ButtonStyle {
    let style: CanvasMenuButton.Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor(isPressed: configuration.isPressed))
            .overlay {
                Rectangle()
                    .strokeBorder(Color.gray500, lineWidth: 1)
            }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed { return .gray100 }
        return style == .primary ? .whiteFixed : .white75
    }
}
