//
//  BorderHistory.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

/// C-105·C-306 테두리 편집의 undo/redo 이력. 색·굵기를 **값 스냅샷**으로 쌓는다.
///
/// C-104 마스크 편집은 이 타입을 쓰지 않는다 — 그쪽은 스냅샷이 아니라 스트로크(변경분)를
/// 쌓았다가 재생하는 모델이라 `undo` 의 의미가 다르고, 스냅샷으로 바꾸면 되돌리기 단계마다
/// 마스크 이미지 전체를 들고 있어야 한다. 두 모델을 한 타입에 합치지 않는다.
struct BorderHistory: Equatable, Sendable {
    private var undoStack: [ToppingBorder] = []
    private var redoStack: [ToppingBorder] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func record(_ previous: ToppingBorder) {
        undoStack.append(previous)
        redoStack.removeAll()
    }

    mutating func undo(current: ToppingBorder) -> ToppingBorder? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    mutating func redo(current: ToppingBorder) -> ToppingBorder? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }
}
