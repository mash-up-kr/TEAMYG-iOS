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
    /// SUIT 에 없는 글리프 폴백 순서. 일본어(가나·한자) → LINE Seed JP, JP 에 없는 중국어 → LINE Seed TW.
    /// ponytail: 둘 다 Regular 만 있어 SUIT 웨이트와 무관하게 Regular 로 그려짐. 웨이트 파일 추가 시 웨이트별 매핑.
    private static let cascadeFontNames = ["LINESeedJPApp_TTF-Regular", "LINESeedTW_TTF-Regular"]

    // static let = 최초 접근 시 1회만 실행(스레드세이프). 앱 시작 배선 불필요.
    private static let registered: Void = {
        for subdirectory in ["SUIT-ttf", "LINESeed"] {
            for url in Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: subdirectory) ?? [] {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()
    static func registerOnce() { _ = registered }

    /// SUIT + 일본어·중국어 폴백(cascade). 미등록 시 systemFont.
    static func uiFont(_ weight: Suit, size: CGFloat) -> UIFont {
        registerOnce()
        guard let font = UIFont(name: weight.rawValue, size: size) else {
            return .systemFont(ofSize: size)
        }
        let cascadeList = cascadeFontNames.map { UIFontDescriptor(fontAttributes: [.name: $0]) }
        return UIFont(
            descriptor: font.fontDescriptor.addingAttributes([.cascadeList: cascadeList]),
            size: size
        )
    }
}

public extension UIFont {
    /// 토큰에 없는 임의 크기의 SUIT Regular. 크기가 연속으로 바뀌는 캔버스 텍스트(자동 축소·핀치) 전용 —
    /// 고정 스펙 텍스트는 `Typography` 토큰을 쓴다.
    static func suit(size: CGFloat) -> UIFont {
        SuitFont.uiFont(.regular, size: size)
    }
}
