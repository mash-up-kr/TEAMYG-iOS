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
    /// 입력 중 캔버스 크기. 있으면 입력창을 이 크기로 고정한다 (너비 = 줄바꿈 너비) — 글자·줄마다 입력창 크기가 바뀌면
    /// 그 프레임에 커서 자리를 못 구해 커서가 입력창 왼쪽 위 점으로 깜빡였다 (실기기 120Hz).
    let inputCanvasSize: CGSize?
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

            // 배치: 줄바꿈 너비가 측정한 글자 너비와 같아지도록 좌우 대칭으로 둔다 — 정렬이 박스 기준이 된다.
            // 입력: 입력창을 캔버스 크기로 고정하고, 정렬한 글이 박스 자리에 오도록 입력창만 옮긴다.
            let textViewSize = inputCanvasSize ?? touchSize
            let textInset = inputCanvasSize == nil
                ? UIEdgeInsets(
                    top: (touchSize.height - textSize.height) / 2,
                    left: (touchSize.width - textSize.width) / 2,
                    bottom: 0,
                    right: (touchSize.width - textSize.width) / 2
                )
                : .zero
            let textViewOffset = inputCanvasSize.map(inputTextViewOffset) ?? .zero

            TextToppingTextView(
                text: text,
                fontSize: fontSize,
                color: UIColor(Color(hex: color.textHex)),
                alignment: alignment.textAlignment,
                textInset: textInset,
                // 키운 입력창이 박스 밖 탭(입력 닫기)을 가로채지 않게 터치는 박스 자리에서만 받는다.
                touchRect: inputCanvasSize == nil ? nil : CGRect(
                    x: (textViewSize.width - touchSize.width) / 2 - textViewOffset.width,
                    y: (textViewSize.height - touchSize.height) / 2 - textViewOffset.height,
                    width: touchSize.width,
                    height: touchSize.height
                ),
                isEditing: isEditing,
                isTransformEnabled: !TextToppingLayout.isBlank(text),
                draft: $draft,
                onTextChange: onTextChange,
                onEditingEnd: onEditingEnd,
                onTransformBegin: onTransformBegin,
                onTransformCommit: onTransformCommit
            )
            .frame(width: textViewSize.width, height: textViewSize.height)
            .offset(textViewOffset)
        }
    }

    /// 입력창(캔버스 크기, 글은 위에서부터) 안에서 정렬된 글이 박스(글자 크기) 자리에 오도록 옮기는 거리.
    private func inputTextViewOffset(canvasSize: CGSize) -> CGSize {
        let horizontalSlack = (canvasSize.width - textSize.width) / 2
        let horizontal: CGFloat = switch alignment {
        case .left: horizontalSlack
        case .center: 0
        case .right: -horizontalSlack
        }
        return CGSize(width: horizontal, height: (canvasSize.height - textSize.height) / 2)
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
