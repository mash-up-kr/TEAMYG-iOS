import SwiftUI

/// SUIT 폰트 패밀리. 웨이트 이름과 폰트 파일 등록만 담당하는 저수준 계층.
/// 실제 텍스트 스타일은 Typography 토큰(Typography+.swift)으로만 사용한다.
enum Suit: String, CaseIterable, Sendable {
    case regular = "SUIT-Regular"
    case medium = "SUIT-Medium"
    case semiBold = "SUIT-SemiBold"
    case bold = "SUIT-Bold"
}

enum SuitFont {
    // static let = 최초 접근 시 1회만 실행(스레드세이프). 앱 시작 배선 불필요.
    private static let registered: Void = {
        for weight in Suit.allCases {
            guard let url = Bundle.module.url(
                forResource: weight.rawValue,
                withExtension: "ttf",
                subdirectory: "SUIT-ttf"
            ) else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
    static func registerOnce() { _ = registered }
}
