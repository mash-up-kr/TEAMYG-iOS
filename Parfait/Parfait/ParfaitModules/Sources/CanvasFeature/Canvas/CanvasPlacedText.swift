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

/// C-106 이 저장을 마친 결과 — 캔버스가 재조회 전에 바로 반영해 고치기 전 모습이 비치지 않게 한다.
public enum TextToppingChange: Sendable {
    /// 새로 쌓았거나 고쳤다.
    case saved(CanvasStore.CanvasText)
    case deleted(textID: Int)
}

extension CanvasStore.CanvasContent {
    func applying(_ change: TextToppingChange) -> Self {
        var texts = texts
        switch change {
        case .saved(let text):
            texts.removeAll { $0.id == text.id }
            texts.append(text)
        case .deleted(let textID):
            texts.removeAll { $0.id == textID }
        }
        return Self(background: background, images: images, texts: texts)
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
    /// `nil` 이면 탭을 받지 않아 아래 토핑으로 넘긴다 (편집 화면·저장본).
    var onTap: (() -> Void)?

    var body: some View {
        let fontSize = TextToppingLayout.maximumFontSize
            * canvasSize.width / TextToppingLayout.designCanvasWidth
            * CGFloat(canvasText.scale)
        let textSize = TextToppingLayout.textSize(
            of: canvasText.text,
            fontSize: fontSize,
            maxWidth: .greatestFiniteMagnitude
        )
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
