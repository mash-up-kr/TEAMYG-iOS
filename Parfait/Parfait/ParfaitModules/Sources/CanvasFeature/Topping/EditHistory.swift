//
//  EditHistory.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import Foundation

struct EditHistory<Value: Equatable & Sendable>: Equatable, Sendable {
    private var undoStack: [Value] = []
    private var redoStack: [Value] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func record(_ previous: Value) {
        undoStack.append(previous)
        redoStack.removeAll()
    }

    mutating func undo(current: Value) -> Value? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    mutating func redo(current: Value) -> Value? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }
}
