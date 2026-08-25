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
        case .white: "#FAFAFA"
        case .black: "#0E0E0E"
        case .pink: "#FCC2CC"
        case .orange: "#FCE7C2"
        case .yellow: "#FAFAAB"
        case .green: "#C5FFD7"
        case .sky: "#C2E4FC"
        case .purple: "#DCC2FC"
        }
    }

    var strokeColor: Color? {
        hex.map { Color(hex: $0) }
    }

    var chipColor: Color {
        strokeColor ?? Color(hex: "#FAFAFA")
    }

    var needsChipOutline: Bool {
        self == .none || self == .white
    }
}

struct ToppingBorder: Equatable, Sendable {
    static let widthRange: ClosedRange<Double> = 0.005...0.05
    static let defaultWidth: Double = 0.02

    var color: ToppingBorderColor = .none
    var width: Double = ToppingBorder.defaultWidth

    var isVisible: Bool {
        color != .none
    }
}

extension ToppingBorder {
    var style: ToppingBorderStyle {
        guard let hex = color.hex else { return .none }
        return .solid(colorHex: hex, width: width)
    }
}

struct BorderSilhouette: Equatable, Sendable {
    let image: CGImage

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.image === rhs.image
    }
}

struct ToppingBorderEditor: Equatable, Sendable {
    private(set) var border = ToppingBorder()
    private var history = EditHistory<ToppingBorder>()
    private var widthBaseline: ToppingBorder?

    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }

    mutating func changeWidth(_ width: Double) {
        border.width = width
    }

    mutating func updateWidthEditing(_ isEditing: Bool) {
        guard !isEditing else {
            widthBaseline = border
            return
        }
        guard let baseline = widthBaseline else { return }
        widthBaseline = nil
        guard baseline != border else { return }
        history.record(baseline)
    }

    mutating func select(_ color: ToppingBorderColor) {
        guard color != border.color else { return }
        history.record(border)
        border.color = color
    }

    mutating func undo() {
        guard let previous = history.undo(current: border) else { return }
        border = previous
    }

    mutating func redo() {
        guard let next = history.redo(current: border) else { return }
        border = next
    }
}

extension ToppingBorderEditor {
    mutating func apply(_ intent: ToppingAddStore.Intent) -> Bool {
        switch intent {
        case .borderWidthChanged(let width): changeWidth(width)
        case .borderColorSelected(let color): select(color)
        case .borderUndoTapped: undo()
        case .borderRedoTapped: redo()
        case .borderWidthEditingChanged(let isEditing):
            updateWidthEditing(isEditing)
            return false
        default:
            return false
        }
        return true
    }
}
