//
//  CanvasPalette.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

/// 캔버스 배경·토핑 테두리가 공유하는 색 목록.
enum CanvasPalette {
    static let white = "#FAFAFA"
    static let black = "#0E0E0E"
    static let pink = "#FCC2CC"
    static let orange = "#FCE7C2"
    static let yellow = "#F9F9AB"
    static let green = "#C5FFD7"
    static let sky = "#C2E4FC"
    static let purple = "#DCC2FC"

    static let all: [String] = [white, black, pink, orange, yellow, green, sky, purple]

    /// HEX 는 서버·안드로이드와 오갈 때 대소문자가 갈릴 수 있어 비교 전에 맞춘다.
    static func matches(_ lhs: String?, _ rhs: String) -> Bool {
        lhs?.uppercased() == rhs.uppercased()
    }
}
