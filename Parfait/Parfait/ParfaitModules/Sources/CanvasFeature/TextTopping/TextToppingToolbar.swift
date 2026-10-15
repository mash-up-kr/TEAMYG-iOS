//
//  TextToppingToolbar.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/14/26.
//

import SwiftUI
import UIComponent

/// 키보드 바로 위 플로팅 툴바 — [색] [타입] [정렬] · 글자 수.
struct TextToppingToolbar: View {
    static let height: CGFloat = 52
    private static let buttonLength: CGFloat = 36

    let color: TextToppingColor
    let type: TextToppingType
    let alignment: TextToppingAlignment
    let characterCount: Int
    let onColorTap: () -> Void
    let onTypeTap: () -> Void
    let onAlignmentTap: () -> Void

    var body: some View {
        HStack(spacing: .gap2) {
            Button(action: onColorTap) {
                Circle()
                    .fill(Color(hex: color.textHex))
                    .overlay {
                        Circle()
                            .strokeBorder(.black5, lineWidth: 1)
                    }
                    .frame(width: 24, height: 24)
                    .frame(width: Self.buttonLength, height: Self.buttonLength)
            }

            Button(action: onTypeTap) {
                typeIcon
            }
            .buttonStyle(TextToppingToolButtonStyle())

            Button(action: onAlignmentTap) {
                alignmentIcon
                    .resizable()
                    .frame(width: Self.buttonLength, height: Self.buttonLength)
            }
            .buttonStyle(TextToppingToolButtonStyle())

            Spacer(minLength: 0)

            Text("\(characterCount)/\(TextToppingLayout.characterLimit)")
                .suit(.caption01Medium)
                .foregroundStyle(characterCount >= TextToppingLayout.characterLimit ? .cherry500 : .gray500)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, .padding7)
        .frame(height: Self.height)
        .background {
            // iOS 26 글라스 키보드는 위 모서리가 둥글고 화면 가장자리에서 떨어져 있어 툴바와 키보드 사이에 틈이 보인다.
            // 배경만 키보드 뒤까지 내려 그 틈을 메운다 — 툴바 프레임(높이·위치)은 그대로.
            Color.white75
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    /// Figma `Button-Text-Type` 모양(36×36, 모서리 8, 안쪽 1pt 테두리)에 지금 고른 색을 캔버스 텍스트와
    /// 같은 규칙으로 입힌다 — 글자색 = 테두리색, Fill 이면 배경색.
    private var typeIcon: some View {
        let shape = RoundedRectangle(cornerRadius: TextToppingToolButtonStyle.cornerRadius)

        return Image.icTextType
            .renderingMode(.template)
            .resizable()
            .foregroundStyle(Color(hex: color.textHex))
            .frame(width: Self.buttonLength, height: Self.buttonLength)
            .background(type.hasFill ? Color(hex: color.fillHex) : .clear, in: shape)
            .overlay {
                if type.hasStroke {
                    shape
                        .strokeBorder(Color(hex: color.textHex), lineWidth: 1)
                }
            }
    }

    private var alignmentIcon: Image {
        switch alignment {
        case .center: .icAlignCenter
        case .left: .icAlignLeft
        case .right: .icAlignRight
        }
    }
}

/// 툴바 버튼 눌림 상태 — 둥근 사각형에 옅은 배경 (Figma `Button-Align` Status=Pressed).
private struct TextToppingToolButtonStyle: ButtonStyle {
    static let cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color.black5 : .clear,
                in: RoundedRectangle(cornerRadius: Self.cornerRadius)
            )
    }
}

/// 툴바 위 컬러칩 팝오버. 고른 색이 글자색이 된다.
struct TextToppingColorPopover: View {
    static let height: CGFloat = 60

    let selectedColor: TextToppingColor
    let onSelect: (TextToppingColor) -> Void

    var body: some View {
        HStack(spacing: .gap3) {
            ForEach(TextToppingColor.allCases, id: \.self) { color in
                CanvasColorChip(hex: color.textHex, isSelected: color == selectedColor) {
                    onSelect(color)
                }
            }
        }
        .padding(.leading, .padding7)
        .padding(.top, .padding5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height, alignment: .top)
        .background(.white50)
    }
}
