//
//  ToppingTransformGesture.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

import CoreGraphics
import SwiftUI

/// 토핑 배치 제스처의 진행 중 값. 확정 전까지는 로컬 상태로만 들고 있다가
/// 제스처가 끝날 때 한 번만 intent 로 올린다 (`docs/mvi.md` 바인딩 절).
///
/// C-106(신규 배치)과 C-305(기존 토핑 편집)가 같은 값을 쓴다 — 두 화면의 이동·크기·회전 동작은
/// 동일하다고 정책이 못박고 있다 (`canvas-policy.md` §6.4.4).
struct ToppingTransformDraft: Equatable {
    private(set) var translation: CGSize = .zero
    private(set) var scaleFactor: Double = 1
    private(set) var rotationDegrees: Double = 0

    /// 회전 제스처가 반 바퀴를 넘을 때 각도가 접히지 않도록, 직전 프레임의 원시 각도를 들고 있는다.
    private var lastRawRotation: Double?
    private var isDragging = false
    private var isPinching = false
    private var isDragSuppressedByPinch = false

    func applied(to placement: ToppingPlacement, in canvasSize: CGSize) -> ToppingPlacement {
        placement
            .magnified(by: scaleFactor)
            .moved(by: translation, in: canvasSize)
            .rotated(by: rotationDegrees)
    }

    /// `rotation(from:to:in:)` 은 `[-180, 180]` 으로 접힌 값을 준다. 그대로 쓰면 한 드래그에서
    /// 180°를 지나는 순간 토핑이 반대로 홱 뒤집힌다 (`canvas-policy.md` §6.4.3 "회전 각도 제한은 없다").
    /// 프레임 간 변화량만 누적해 래핑을 푼다.
    private mutating func accumulateRotation(rawDegrees: Double) {
        guard let lastRawRotation else {
            self.lastRawRotation = rawDegrees
            rotationDegrees = rawDegrees
            return
        }
        rotationDegrees += remainder(rawDegrees - lastRawRotation, 360)
        self.lastRawRotation = rawDegrees
    }

    mutating func scaleByHandle(magnification: Double) {
        scaleFactor = magnification
    }

    mutating func endScaleByHandle() -> Double {
        let committed = scaleFactor
        resetTransform()
        return committed
    }

    mutating func rotateByHandle(rawDegrees: Double) {
        accumulateRotation(rawDegrees: rawDegrees)
    }

    mutating func endRotateByHandle() -> Double {
        let committed = rotationDegrees
        resetTransform()
        return committed
    }

    mutating func drag(translation: CGSize) {
        isDragging = true
        guard !isDragSuppressedByPinch else { return }
        self.translation = translation
    }

    mutating func endDrag() -> CGSize? {
        let wasSuppressed = isDragSuppressedByPinch
        let committed = translation
        isDragging = false
        isDragSuppressedByPinch = false
        if isPinching {
            translation = .zero
        } else {
            resetTransform()
        }
        return wasSuppressed ? nil : committed
    }

    mutating func pinch(magnification: Double?, rotationDegrees rawDegrees: Double?) {
        isPinching = true
        isDragSuppressedByPinch = true
        translation = .zero
        if let magnification {
            scaleFactor = magnification
        }
        if let rawDegrees {
            accumulateRotation(rawDegrees: rawDegrees)
        }
    }

    mutating func endPinch() -> (scaleFactor: Double, rotationDegrees: Double) {
        let committed = (scaleFactor: scaleFactor, rotationDegrees: rotationDegrees)
        isPinching = false
        if !isDragging {
            isDragSuppressedByPinch = false
        }
        resetTransform()
        return committed
    }

    private mutating func resetTransform() {
        translation = .zero
        scaleFactor = 1
        rotationDegrees = 0
        lastRawRotation = nil
    }
}

struct ToppingPinchGesture: Gesture {
    @Binding var draft: ToppingTransformDraft
    let onCommit: (Double, Double) -> Void

    var body: some Gesture {
        SimultaneousGesture(MagnifyGesture(), RotateGesture())
            .onChanged { value in
                draft.pinch(magnification: magnification(of: value), rotationDegrees: rotationDegrees(of: value))
            }
            .onEnded { _ in
                let transform = draft.endPinch()
                onCommit(transform.scaleFactor, transform.rotationDegrees)
            }
    }

    private func magnification(of value: SimultaneousGesture<MagnifyGesture, RotateGesture>.Value) -> Double? {
        value.first.map { Double($0.magnification) }
    }

    private func rotationDegrees(of value: SimultaneousGesture<MagnifyGesture, RotateGesture>.Value) -> Double? {
        value.second?.rotation.degrees
    }
}
