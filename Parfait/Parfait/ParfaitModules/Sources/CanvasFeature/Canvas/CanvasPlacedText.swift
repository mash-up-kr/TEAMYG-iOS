//
//  CanvasPlacedText.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/26/26.
//

import CanvasDomain
import SwiftUI
import UIComponent

public extension CanvasStore {
    /// 캔버스에 그릴 텍스트. 색·타입은 서버 값에서 미리 풀어 둔다.
    struct CanvasText: Equatable, Identifiable, Sendable {
        public let id: Int
        let text: String
        let positionX: Double
        let positionY: Double
        let positionZ: Double
        let scale: Double
        let rotation: Double
        let textHex: String
        let fillHex: String
        let type: TextToppingType
        let alignment: PlacedTextAlignment
        let isMine: Bool
    }
}

extension CanvasStore.CanvasContent {
    /// C-106 이 쌓은 텍스트를 재조회 전에 바로 얹는다 — 닫히는 동안 캔버스에서 빠져 보이지 않게.
    func adding(_ text: CanvasStore.CanvasText) -> Self {
        Self(background: background, images: images, texts: texts + [text])
    }
}

/// 캔버스에 쌓는 한 장 — 이미지와 텍스트가 같은 `positionZ` 축에 섞인다.
enum CanvasLayer: Identifiable {
    case image(CanvasStore.CanvasImage)
    case text(CanvasStore.CanvasText)

    var id: LayerID {
        switch self {
        case .image(let image): .image(image.id)
        case .text(let text): .text(text.id)
        }
    }

    var positionZ: Double {
        switch self {
        case .image(let image): image.positionZ
        case .text(let text): text.positionZ
        }
    }

    /// 이미지·텍스트 id 는 서버에서 따로 매겨져 겹칠 수 있다.
    enum LayerID: Hashable {
        case image(Int)
        case text(Int)
    }
}

/// 서버에 저장된 텍스트를 캔버스에 그린다. 받은 글을 다시 줄바꿈하지 않고 개행만 따른다 — 배치(C-106-Arrange)와 같은 규칙.
/// 글자 크기 = 기본 크기 × `scale` (작성자의 자동 축소분은 `scale` 에 합쳐져 온다).
struct CanvasPlacedText: View {
    let canvasText: CanvasStore.CanvasText
    let canvasSize: CGSize
    /// 편집 화면에서 고른 텍스트 — 사진과 같은 점선 테두리를 두른다.
    var isSelected = false
    /// `nil` 이면 탭을 받지 않아 아래 토핑으로 넘긴다 (편집 화면·저장본).
    var onTap: (() -> Void)?

    var body: some View {
        let fontSize = Self.fontSize(of: canvasText, canvasSize: canvasSize)
        let textSize = Self.textSize(of: canvasText, fontSize: fontSize)
        let boxSize = TextToppingBox.boxSize(textSize: textSize, fontSize: fontSize, type: canvasText.type)

        ZStack {
            if canvasText.type.hasFill {
                TextToppingBackground(
                    boxSize: boxSize,
                    fontSize: fontSize,
                    fillHex: canvasText.fillHex,
                    strokeHex: canvasText.type.hasStroke ? canvasText.textHex : nil
                )
            }

            lines(fontSize: fontSize)
                .frame(width: textSize.width, height: textSize.height)
        }
        .overlay {
            if isSelected {
                ToppingSelectionFrame(renderedSize: boxSize)
            }
        }
        // 작은 글도 누를 수 있게 터치 영역은 최소 44 — 배치 화면과 같은 기준.
        .frame(
            width: max(boxSize.width, ToppingPlacement.minimumHitLength),
            height: max(boxSize.height, ToppingPlacement.minimumHitLength)
        )
        .contentShape(.rect)
        .onTapGesture { onTap?() }
        .allowsHitTesting(onTap != nil)
        .rotationEffect(.degrees(canvasText.rotation))
        .position(x: canvasText.positionX * canvasSize.width, y: canvasText.positionY * canvasSize.height)
    }

    /// 네모배경까지 포함한 박스 크기 — 탭 판정·모서리 X 자리에 쓴다.
    static func boxSize(of canvasText: CanvasStore.CanvasText, canvasSize: CGSize) -> CGSize {
        let fontSize = fontSize(of: canvasText, canvasSize: canvasSize)
        return TextToppingBox.boxSize(
            textSize: textSize(of: canvasText, fontSize: fontSize),
            fontSize: fontSize,
            type: canvasText.type
        )
    }

    private static func fontSize(of canvasText: CanvasStore.CanvasText, canvasSize: CGSize) -> CGFloat {
        TextToppingLayout.maximumFontSize
            * canvasSize.width / TextToppingLayout.designCanvasWidth
            * CGFloat(canvasText.scale)
    }

    private static func textSize(of canvasText: CanvasStore.CanvasText, fontSize: CGFloat) -> CGSize {
        TextToppingLayout.textSize(of: canvasText.text, fontSize: fontSize, maxWidth: .greatestFiniteMagnitude)
    }

    /// 줄마다 줄높이(글자 크기 × 1.4) 칸 가운데에 글리프를 둔다 — `TextToppingLayout.attributes` 의 줄높이·baselineOffset 과 같은 모양.
    private func lines(fontSize: CGFloat) -> some View {
        let font = Font(UIFont.suit(size: fontSize))
        let lineHeight = fontSize * TextToppingLayout.lineHeightMultiple

        return VStack(alignment: canvasText.alignment.horizontalAlignment, spacing: 0) {
            ForEach(Array(canvasText.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(font)
                    .kerning(TextToppingLayout.kern(fontSize: fontSize))
                    .foregroundStyle(Color(hex: canvasText.textHex))
                    .fixedSize()
                    .frame(height: lineHeight)
            }
        }
    }
}

private extension PlacedTextAlignment {
    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }
}

private extension CanvasStore.CanvasText {
    /// 빈 줄(연속 개행·끝 개행)도 한 줄 — `TextToppingLayout.textSize` 의 줄 수와 맞춘다.
    var lines: [String] {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
    }
}
