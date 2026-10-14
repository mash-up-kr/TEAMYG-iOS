//
//  TextToppingStyle.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/14/26.
//

import UIKit

/// 텍스트 색 팝오버의 칩. 고른 색이 곧 글자색·테두리색이고, 배경 타입일 때만 짝지은 배경색이 붙는다
/// (Figma `텍스트 타입 - 컬러 매핑 규칙`).
enum TextToppingColor: CaseIterable, Sendable {
    case white
    case black
    case pink
    case orange
    case yellow
    case green
    case blue
    case violet

    var textHex: String {
        switch self {
        case .white: "#FAFAFA"
        case .black: "#0E0E0E"
        case .pink: "#FA91A2"
        case .orange: "#FFBB42"
        case .yellow: "#FFD21F"
        case .green: "#64DB88"
        case .blue: "#6DBBF2"
        case .violet: "#CEA8FC"
        }
    }

    var fillHex: String {
        switch self {
        case .white: "#0E0E0E"
        case .black: "#FAFAFA"
        case .pink: "#FFF9FA"
        case .orange: "#FFFBF3"
        case .yellow: "#FEFEF6"
        case .green: "#F4FCF7"
        // 보라 배경이 파랑과 같은 값인 건 디자인 의도 (2026-10-14 확인).
        case .blue, .violet: "#F6FBFE"
        }
    }
}

/// 툴바 [타입] 버튼이 탭마다 순환하는 배경 타입.
enum TextToppingType: Sendable {
    case plain
    case fill
    case fillStroke

    var next: Self {
        switch self {
        case .plain: .fill
        case .fill: .fillStroke
        case .fillStroke: .plain
        }
    }

    var hasFill: Bool { self != .plain }
    var hasStroke: Bool { self == .fillStroke }
}

/// 툴바 [정렬] 버튼이 탭마다 순환하는 정렬. 가운데에서 시작한다.
enum TextToppingAlignment: Sendable {
    case center
    case left
    case right

    var next: Self {
        switch self {
        case .center: .left
        case .left: .right
        case .right: .center
        }
    }

    var textAlignment: NSTextAlignment {
        switch self {
        case .center: .center
        case .left: .left
        case .right: .right
        }
    }
}
