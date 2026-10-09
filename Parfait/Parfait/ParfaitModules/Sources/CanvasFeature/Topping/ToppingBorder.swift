//
//  ToppingBorder.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import SwiftUI
import UIComponent

enum ToppingBorderColor: String, CaseIterable, Identifiable, Sendable {
    case none
    case white
    case black
    case pink
    case orange
    case yellow
    case green
    case sky
    case purple

    var id: String { rawValue }

    var hex: String? {
        switch self {
        case .none: nil
        case .white: CanvasPalette.white
        case .black: CanvasPalette.black
        case .pink: CanvasPalette.pink
        case .orange: CanvasPalette.orange
        case .yellow: CanvasPalette.yellow
        case .green: CanvasPalette.green
        case .sky: CanvasPalette.sky
        case .purple: CanvasPalette.purple
        }
    }

    var strokeColor: Color? {
        hex.map { Color(hex: $0) }
    }

    var chipColor: Color {
        strokeColor ?? Color(hex: CanvasPalette.white)
    }

    init?(hex: String) {
        guard let color = Self.allCases.first(where: { CanvasPalette.matches($0.hex, hex) }) else { return nil }
        self = color
    }
}

struct ToppingBorder: Equatable, Sendable {
    /// 굵기 범위는 Domain 계약이 원본이다 — 슬라이더 상한과 저장 검증이 갈리면
    /// 넣을 수는 있는데 저장에서 튕기는 상태가 된다.
    static let widthRange: ClosedRange<Double> = ToppingBorderStyle.widthRange
    static let defaultWidth: Double = 4

    var color: ToppingBorderColor = .none
    var width: Double = ToppingBorder.defaultWidth

    var isVisible: Bool {
        color != .none
    }
}

extension ToppingBorder {
    init(_ border: CanvasStore.CanvasImageBorder?) {
        guard let border else {
            self.init()
            return
        }
        self.init(
            color: ToppingBorderColor(hex: border.colorHex) ?? .none,
            width: border.width
        )
    }

    var style: ToppingBorderStyle {
        guard let hex = color.hex else { return .none }
        return .solid(colorHex: hex, width: width)
    }

    var canvasImageBorder: CanvasStore.CanvasImageBorder? {
        guard let hex = color.hex else { return nil }
        return CanvasStore.CanvasImageBorder(colorHex: hex, width: width)
    }
}

struct BorderSilhouette: Equatable, Sendable {
    let image: CGImage

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.image === rhs.image
    }
}
