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

/// 브러시 굵기는 `scale 1.0`(뷰포트 Aspect Fit) 화면 기준 pt 다. 확대해도 마스크에 닿는 크기는 그대로다
/// (`topping_ui.md` §6.2). Figma 프리뷰 원이 38pt 라 `2~50` 은 pt 로 읽어야 맞는다.
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
    var hasEdits: Bool { !strokes.isEmpty }

    mutating func reset() {
        self = Self()
    }

    /// 마스크를 다시 그려야 하는 변경이면 `true`.
    mutating func apply(_ intent: ToppingAddStore.Intent) -> Bool {
        switch intent {
        case .brushModeSelected(let mode):
            brush.mode = mode
            return false
        case .brushDiameterChanged(let diameter):
            brush.diameter = diameter
            return false
        case .brushStrokeEnded(let stroke):
            return record(stroke)
        case .maskUndoTapped:
            return undo()
        case .maskRedoTapped:
            return redo()
        default:
            return false
        }
    }

    private mutating func record(_ stroke: ToppingBrushStroke) -> Bool {
        guard !stroke.points.isEmpty else { return false }
        strokes.append(stroke)
        undoneStrokes.removeAll()
        return true
    }

    private mutating func undo() -> Bool {
        guard let stroke = strokes.popLast() else { return false }
        undoneStrokes.append(stroke)
        return true
    }

    private mutating func redo() -> Bool {
        guard let stroke = undoneStrokes.popLast() else { return false }
        strokes.append(stroke)
        return true
    }
}
