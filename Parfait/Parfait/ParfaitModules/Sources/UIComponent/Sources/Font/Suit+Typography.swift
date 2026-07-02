import SwiftUI
import UIKit

/// 파르페 디자인 폰트
public struct Typography: Sendable {
    let weight: Suit
    let size: CGFloat
    let lineHeight: CGFloat     // 배수. 140% → 1.4
    let letterSpacing: CGFloat  // 퍼센트. -1.1% → -1.1

    // 스펙은 고정값 → Dynamic Type 스케일 끔(fixedSize). 켜면 줄높이 박스가 깨짐.
    var font: Font {
        SuitFont.registerOnce()
        return .custom(weight.rawValue, fixedSize: size)
    }
    
    // 자간(pt) = 크기 × 퍼센트. Figma letter spacing 과 동일.
    var tracking: CGFloat { size * letterSpacing / 100 }

    // 목표 줄높이 − 폰트 고유 줄높이 = 줄 사이 추가 간격.
    // ponytail: lineHeight < 폰트 고유높이면 음수(SwiftUI 가 0으로 클램프) — 줄높이 축소는 SwiftUI 로 불가. 현 토큰은 전부 여유 있음.
    var lineSpacing: CGFloat {
        size * lineHeight - uiFont.lineHeight
    }
}

// MARK: - 디자인 시스템

public extension Typography {
    static let title01Bold = Typography(weight: .bold, size: 24, lineHeight: 1.4, letterSpacing: -1.1)
    static let title01SemiBold = Typography(weight: .semiBold, size: 24, lineHeight: 1.4, letterSpacing: -1.1)
    static let title02Bold = Typography(weight: .bold, size: 20, lineHeight: 1.4, letterSpacing: -1.1)
    static let title02SemiBold = Typography(weight: .semiBold, size: 20, lineHeight: 1.4, letterSpacing: -1.1)
    static let title03Bold = Typography(weight: .bold, size: 18, lineHeight: 1.4, letterSpacing: -1.1)
    static let title03SemiBold = Typography(weight: .semiBold, size: 18, lineHeight: 1.4, letterSpacing: -1.1)

    static let body01Bold = Typography(weight: .bold, size: 16, lineHeight: 1.5, letterSpacing: -1.1)
    static let body01SemiBold = Typography(weight: .semiBold, size: 16, lineHeight: 1.5, letterSpacing: -1.1)
    static let body01Regular = Typography(weight: .regular, size: 16, lineHeight: 1.5, letterSpacing: -1.1)
    static let body02Bold = Typography(weight: .bold, size: 14, lineHeight: 1.5, letterSpacing: -1.1)
    static let body02SemiBold = Typography(weight: .semiBold, size: 14, lineHeight: 1.5, letterSpacing: -1.1)
    static let body02Regular = Typography(weight: .regular, size: 14, lineHeight: 1.5, letterSpacing: -1.1)

    static let caption01Medium = Typography(weight: .medium, size: 12, lineHeight: 1.5, letterSpacing: -1.1)
    static let caption01Regular = Typography(weight: .regular, size: 12, lineHeight: 1.5, letterSpacing: -1.1)
}

// MARK: - UIKIt 용

extension Typography {
    
    /// UIKit 용. 등록 보장 후 반환 (미등록 시 systemFont 폴백). 단독 사용 금지 → attributes 로 전체 스펙 적용.
    var uiFont: UIFont {
        return UIFont(name: weight.rawValue, size: size) ?? .systemFont(ofSize: size)
    }

    /// UIKit 용. 폰트·자간·줄높이 전체 스펙. SwiftUI 는 .suit() 사용.
    var attributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = size * lineHeight
        paragraphStyle.maximumLineHeight = size * lineHeight
        return [
            .font: uiFont,
            .kern: tracking,
            .paragraphStyle: paragraphStyle,
            // 줄박스 안 글리프 세로 중앙 정렬(Figma 와 동일). iOS 16.4+ 는 offset 1배 적용 → /2.
            .baselineOffset: (size * lineHeight - uiFont.lineHeight) / 2
        ]
    }

}
