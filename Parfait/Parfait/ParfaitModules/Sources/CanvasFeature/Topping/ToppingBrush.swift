//
//  ToppingBrush.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import Foundation

enum ToppingBrushMode: Equatable, Sendable {
    /// 최종 누끼에서 제외한다.
    case erase
    /// 최종 누끼에 포함한다.
    case fill
}

struct ToppingBrushStroke: Equatable, Sendable {
    let mode: ToppingBrushMode
    let diameter: Double
    var points: [CGPoint]
}

struct ToppingBrush: Equatable, Sendable {
    static let diameterRange: ClosedRange<Double> = 2...50
    static let defaultDiameter: Double = 20

    var mode: ToppingBrushMode = .erase
    var diameter: Double = ToppingBrush.defaultDiameter
}

struct ToppingMaskEditor: Equatable, Sendable {
    static let minimumScale: CGFloat = 1
    static let maximumScale: CGFloat = 3
    static let viewportMargin: CGFloat = 10

    private(set) var brush = ToppingBrush()
    private(set) var strokes: [ToppingBrushStroke] = []
    private var undoneStrokes: [ToppingBrushStroke] = []

    var canUndo: Bool { !strokes.isEmpty }
    var canRedo: Bool { !undoneStrokes.isEmpty }

    mutating func reset() {
        self = Self()
    }

    mutating func selectBrushMode(_ mode: ToppingBrushMode) {
        brush.mode = mode
    }

    mutating func changeBrushDiameter(_ diameter: Double) {
        brush.diameter = diameter
    }

    mutating func record(_ stroke: ToppingBrushStroke) -> Bool {
        guard !stroke.points.isEmpty else { return false }
        strokes.append(stroke)
        undoneStrokes.removeAll()
        return true
    }

    mutating func undo() -> Bool {
        guard let stroke = strokes.popLast() else { return false }
        undoneStrokes.append(stroke)
        return true
    }

    mutating func redo() -> Bool {
        guard let stroke = undoneStrokes.popLast() else { return false }
        strokes.append(stroke)
        return true
    }
}
