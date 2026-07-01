import SwiftUI
import CoreText

public enum SUIT: String, CaseIterable {
    case regular = "SUIT-Regular", medium = "SUIT-Medium"
    case semiBold = "SUIT-SemiBold", bold = "SUIT-Bold"
}

public extension Font {
    /// SUIT 커스텀 폰트. relativeTo 기본값으로 Dynamic Type 스케일 대응.
    static func suit(_ weight: SUIT, size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        SUITFont.registerOnce()
        return .custom(weight.rawValue, size: size, relativeTo: style)
    }
}

enum SUITFont {
    // static let = 최초 접근 시 1회만 실행(스레드세이프). 앱 시작 배선 불필요.
    private static let registered: Void = {
        for weight in SUIT.allCases {
            guard let url = Bundle.module.url(forResource: weight.rawValue,
                                              withExtension: "ttf", subdirectory: "SUIT-ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
    static func registerOnce() { _ = registered }
}
