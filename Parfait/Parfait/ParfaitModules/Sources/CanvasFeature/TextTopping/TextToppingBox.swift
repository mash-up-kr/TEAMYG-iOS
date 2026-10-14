//
//  TextToppingBox.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/14/26.
//

import SwiftUI
import UIComponent

/// 텍스트 박스 한 개 — 네모배경·테두리 + 입력창. 위치·회전은 부모가 정한다.
struct TextToppingBox: View {
    let text: String
    /// 화면 pt, 핀치 배율 포함
    let fontSize: CGFloat
    /// `TextToppingBox.textSize` — 부모가 포커스 테두리·탭 판정에도 쓰므로 한 번만 재서 넘긴다.
    let textSize: CGSize
    /// `TextToppingBox.boxSize`
    let boxSize: CGSize
    let color: TextToppingColor
    let type: TextToppingType
    let alignment: TextToppingAlignment
    let isEditing: Bool
    @Binding var draft: ToppingTransformDraft
    let onTextChange: (String) -> Void
    let onEditingEnd: () -> Void
    let onTransformBegin: () -> Void
    let onTransformCommit: (ToppingTransformDraft) -> Void

    var body: some View {
        // 입력창 프레임·inset 은 타입과 무관하게 늘 Fill 박스 기준 — 타입만 바꿀 땐 입력창을 다시 배치하지 않고
        // 배경만 다시 그린다.
        let fillBoxSize = Self.boxSize(textSize: textSize, fontSize: fontSize, type: .fill)
        let touchSize = CGSize(
            width: max(fillBoxSize.width, ToppingPlacement.minimumHitLength),
            height: max(fillBoxSize.height, ToppingPlacement.minimumHitLength)
        )

        ZStack {
            if type.hasFill {
                background
            }

            if text.isEmpty {
                placeholder
            }

            TextToppingTextView(
                text: text,
                fontSize: fontSize,
                color: UIColor(Color(hex: color.textHex)),
                alignment: alignment.textAlignment,
                // 줄바꿈 너비가 측정한 글자 너비와 같아지도록 좌우 대칭으로 둔다 — 같은 너비로 다시 줄바꿈해도
                // 줄이 바뀌지 않고, 정렬이 박스 기준이 된다.
                textInset: UIEdgeInsets(
                    top: (touchSize.height - textSize.height) / 2,
                    left: (touchSize.width - textSize.width) / 2,
                    bottom: 0,
                    right: (touchSize.width - textSize.width) / 2
                ),
                isEditing: isEditing,
                isTransformEnabled: !TextToppingLayout.isBlank(text),
                draft: $draft,
                onTextChange: onTextChange,
                onEditingEnd: onEditingEnd,
                onTransformBegin: onTransformBegin,
                onTransformCommit: onTransformCommit
            )
            .frame(width: touchSize.width, height: touchSize.height)
        }
    }

    private var background: some View {
        let borderWidth = TextToppingLayout.borderWidth(fontSize: fontSize)

        return Rectangle()
            .fill(Color(hex: color.fillHex))
            .overlay {
                if type.hasStroke {
                    // 테두리는 박스 바깥쪽으로 두른다.
                    Rectangle()
                        .strokeBorder(Color(hex: color.textHex), lineWidth: borderWidth)
                        .padding(-borderWidth)
                }
            }
            .frame(width: boxSize.width, height: boxSize.height)
    }

    private var placeholder: some View {
        Text(TextToppingLayout.placeholder)
            .font(Font(UIFont.suit(size: fontSize)))
            .tracking(TextToppingLayout.kern(fontSize: fontSize))
            .foregroundStyle(Color(hex: color.textHex))
            .lineLimit(1)
            .fixedSize()
            .allowsHitTesting(false)
    }
}

extension TextToppingBox {
    /// 비어 있으면 플레이스홀더 크기로 잡는다.
    static func textSize(of text: String, fontSize: CGFloat, wrapWidth: CGFloat) -> CGSize {
        TextToppingLayout.textSize(
            of: text.isEmpty ? TextToppingLayout.placeholder : text,
            fontSize: fontSize,
            maxWidth: wrapWidth
        )
    }

    /// 글자 + 네모배경 여백. 테두리는 바깥으로 두르므로 포함하지 않는다.
    static func boxSize(textSize: CGSize, fontSize: CGFloat, type: TextToppingType) -> CGSize {
        guard type.hasFill else { return textSize }

        let padding = TextToppingLayout.boxPadding(fontSize: fontSize)
        return CGSize(
            width: textSize.width + padding.horizontal * 2,
            height: textSize.height + padding.vertical * 2
        )
    }
}
