//
//  CanvasPalette.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

/// 캔버스 배경·토핑 테두리가 공유하는 색 목록.
///
/// 디자인 시스템 토큰(`Colors+.swift`)으로 올리지 않는다 — 캔버스 화면에서만 쓰는 값이라는 것이
/// 확정 규약이다 (`canvas_progress.md` §7). 다만 **같은 색은 같은 HEX** 여야 하므로, 배경 팔레트와
/// 테두리 팔레트가 각자 문자열을 들고 있지 않도록 여기 한 곳에서만 정의한다.
/// (노란색이 `#FAFAAB`/`#F9F9AB` 로 갈려 저장 후 재조회하면 색이 바뀌던 버그의 재발 방지.)
enum CanvasPalette {
    static let white = "#FAFAFA"
    static let black = "#0E0E0E"
    static let pink = "#FCC2CC"
    static let orange = "#FCE7C2"
    static let yellow = "#F9F9AB"
    static let green = "#C5FFD7"
    static let sky = "#C2E4FC"
    static let purple = "#DCC2FC"

    /// 배경 팔레트 노출 순서 (`canvas_progress.md` §7).
    static let all: [String] = [white, black, pink, orange, yellow, green, sky, purple]

    /// HEX 는 서버·안드로이드와 오갈 때 대소문자가 갈릴 수 있어 비교 전에 맞춘다.
    static func matches(_ lhs: String?, _ rhs: String) -> Bool {
        lhs?.uppercased() == rhs.uppercased()
    }
}
