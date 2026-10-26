//
//  TextToppingLayout.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/14/26.
//

import UIComponent
import UIKit

/// 캔버스 텍스트의 글자 스타일·측정·자동 크기 계산. 상태 없는 순수 계산만 둔다.
enum TextToppingLayout {
    /// 디자인 기준 캔버스 너비. 화면 배율 = 실제 캔버스 너비 / 이 값.
    static let designCanvasWidth: CGFloat = 335
    /// 디자인 기준 최대 글자 크기.
    static let maximumFontSize: CGFloat = 24
    static let lineHeightMultiple: CGFloat = 1.4
    /// 자간 퍼센트. -1.1% → 글자 크기 × -0.011
    static let letterSpacingPercent: CGFloat = -1.1
    static let characterLimit = 100
    static let placeholder = "텍스트를 입력해 주세요"

    /// 자동 크기 이진 탐색을 멈추는 정밀도(pt).
    private static let fittingPrecision: CGFloat = 0.01

    /// SUIT Regular, kern, 줄높이 고정(min=max=fontSize×1.4), 글리프 세로 중앙(baselineOffset), 정렬, 글자색.
    static func attributes(
        fontSize: CGFloat,
        color: UIColor,
        alignment: NSTextAlignment
    ) -> [NSAttributedString.Key: Any] {
        let font = UIFont.suit(size: fontSize)
        let lineHeight = lineHeight(fontSize: fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.alignment = alignment
        return [
            .font: font,
            .foregroundColor: color,
            .kern: kern(fontSize: fontSize),
            .paragraphStyle: paragraphStyle,
            // 줄박스 안 글리프 세로 중앙 정렬. `Typography.attributes` 와 같은 식 (iOS 16.4+ 는 offset 1배 적용 → /2).
            .baselineOffset: (lineHeight - font.lineHeight) / 2
        ]
    }

    /// maxWidth 에서 줄바꿈했을 때 화면에 보이는 줄들 (자동 줄바꿈 + 사용자 줄바꿈 모두 반영, 줄 끝 개행 문자 제외).
    /// 빈 줄(연속 줄바꿈, 마지막 줄바꿈 뒤 빈 줄)도 "" 로 포함 — 줄 수가 UITextView 와 같아야 한다.
    static func lines(of text: String, fontSize: CGFloat, maxWidth: CGFloat) -> [String] {
        measuredLines(of: text, fontSize: fontSize, maxWidth: maxWidth).map(\.text)
    }

    /// 글자 블록 크기. width = 가장 긴 줄의 실제 너비(ceil), height = 줄 수 × fontSize × lineHeightMultiple.
    /// 빈 문자열은 1줄로 친다.
    static func textSize(of text: String, fontSize: CGFloat, maxWidth: CGFloat) -> CGSize {
        let lines = measuredLines(of: text, fontSize: fontSize, maxWidth: maxWidth)
        let widestLine = lines.map(\.width).max() ?? 0
        return CGSize(
            width: ceil(widestLine),
            height: CGFloat(max(lines.count, 1)) * lineHeight(fontSize: fontSize)
        )
    }

    /// maxWidth 에서 줄바꿈했을 때 높이가 maxHeight 이하가 되는 가장 큰 글자 크기 (≤ maxFontSize, 하한 없음, 연속값).
    /// maxFontSize 로 들어가면 그대로 반환. 이진 탐색, 정밀도 0.01pt 정도면 충분.
    static func fittingFontSize(
        for text: String,
        maxFontSize: CGFloat,
        maxWidth: CGFloat,
        maxHeight: CGFloat
    ) -> CGFloat {
        func fits(_ fontSize: CGFloat) -> Bool {
            textSize(of: text, fontSize: fontSize, maxWidth: maxWidth).height <= maxHeight
        }

        guard !fits(maxFontSize) else { return maxFontSize }

        // ponytail: 글자 크기에 따라 줄바꿈 위치가 바뀌어 높이가 엄밀히 단조롭진 않다. 경계에서 0.01pt 수준 오차는 무시.
        var lowerBound: CGFloat = 0
        var upperBound = maxFontSize
        while upperBound - lowerBound > fittingPrecision {
            let middle = (lowerBound + upperBound) / 2
            if fits(middle) {
                lowerBound = middle
            } else {
                upperBound = middle
            }
        }
        return lowerBound
    }

    /// 앞에서부터 characterLimit 자까지 (Swift Character = 화면 글자 단위, 조합 이모지 1자).
    static func limited(_ text: String) -> String {
        String(text.prefix(characterLimit))
    }

    /// 공백·줄바꿈만 있으면 true.
    static func isBlank(_ text: String) -> Bool {
        text.allSatisfy(\.isWhitespace)
    }

    /// 네모배경 여백·테두리 (글자 크기 s 기준: 좌우 s/3, 상하 s/6, 테두리 s/24).
    static func boxPadding(fontSize: CGFloat) -> (horizontal: CGFloat, vertical: CGFloat) {
        (horizontal: fontSize / 3, vertical: fontSize / 6)
    }

    static func borderWidth(fontSize: CGFloat) -> CGFloat {
        fontSize / 24
    }

    /// 자간(pt) = 글자 크기 × 퍼센트.
    static func kern(fontSize: CGFloat) -> CGFloat {
        fontSize * letterSpacingPercent / 100
    }
}

private extension TextToppingLayout {
    struct MeasuredLine {
        let text: String
        let width: CGFloat
    }

    static func lineHeight(fontSize: CGFloat) -> CGFloat {
        fontSize * lineHeightMultiple
    }

    /// 표시용 `UITextView`(TextKit 1, inset·lineFragmentPadding 0) 와 같은 엔진으로 줄을 나눈다.
    /// 마지막 줄바꿈 뒤 빈 줄(extra line fragment)도 한 줄로 센다.
    static func measuredLines(of text: String, fontSize: CGFloat, maxWidth: CGFloat) -> [MeasuredLine] {
        let textStorage = NSTextStorage(
            string: text,
            attributes: attributes(fontSize: fontSize, color: .black, alignment: .natural)
        )
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        let nsText = text as NSString
        var lines: [MeasuredLine] = []
        layoutManager.enumerateLineFragments(
            forGlyphRange: NSRange(location: 0, length: layoutManager.numberOfGlyphs)
        ) { _, usedRect, _, glyphRange, _ in
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let lineText = nsText.substring(with: characterRange)
            lines.append(
                MeasuredLine(
                    text: lineText.trimmingCharacters(in: .newlines),
                    width: usedRect.width
                )
            )
        }

        if layoutManager.extraLineFragmentTextContainer != nil {
            lines.append(MeasuredLine(text: "", width: 0))
        }
        return lines
    }
}
