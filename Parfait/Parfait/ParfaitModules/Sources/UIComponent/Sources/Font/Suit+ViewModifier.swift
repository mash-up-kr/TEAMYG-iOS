//
//  Suit+ViewModifier.swift
//  ParfaitModules
//
//  Created by Enes on 7/2/26.
//

import SwiftUI

public extension View {
    /// 토큰 전체 스펙(폰트·자간·줄높이) 적용.
    func suit(_ typography: Typography) -> some View {
        modifier(TypographyModifier(typography: typography))
    }
}

struct TypographyModifier: ViewModifier {
    let typography: Typography
    
    func body(content: Content) -> some View {
        let spacing = typography.lineSpacing
        content
            .font(typography.font)
            .tracking(typography.tracking)
            .lineSpacing(spacing)
            .padding(.vertical, spacing / 2) // 첫·끝 줄도 동일 박스 → n줄 모두 size×lineHeight
    }
}

// MARK: - UIKit

public extension UILabel {
    /// 토큰 전체 스펙으로 텍스트 설정. SwiftUI .suit() 의 UIKit 대응.
    /// ponytail: paragraphStyle 이 label 의 lineBreakMode 를 덮음(기본 wordWrap). 말줄임 필요 시 스타일 확장.
    func suit(_ text: String, _ typography: Typography) {
        attributedText = NSAttributedString(string: text, attributes: typography.attributes)
    }
}
