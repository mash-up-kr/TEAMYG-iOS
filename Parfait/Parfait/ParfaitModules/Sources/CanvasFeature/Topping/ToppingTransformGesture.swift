//
//  ToppingTransformGesture.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

import CoreGraphics
import SwiftUI
import UIKit

/// 토핑 배치 제스처의 진행 중 값. 확정 전까지는 로컬 상태로만 들고 있다가
/// 제스처가 끝날 때 한 번만 intent 로 올린다 (`docs/mvi.md` 바인딩 절).
///
/// C-106(신규 배치)과 C-305(기존 토핑 편집)가 같은 값을 쓴다 — 두 화면의 이동·크기·회전 동작은
/// 동일하다고 정책이 못박고 있다 (`canvas-policy.md` §6.4.4).
struct ToppingTransformDraft: Equatable {
    private(set) var translation: CGSize = .zero
    private(set) var scaleFactor: Double = 1
    private(set) var rotationDegrees: Double = 0

    /// 핸들 회전 제스처가 반 바퀴를 넘을 때 각도가 접히지 않도록, 직전 프레임의 원시 각도를 들고 있는다.
    private var lastRawRotation: Double?

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

    mutating func move(by delta: CGSize) {
        translation.width += delta.width
        translation.height += delta.height
    }

    mutating func magnify(by factor: Double) {
        scaleFactor *= factor
    }

    mutating func rotate(byDegrees degrees: Double) {
        rotationDegrees += degrees
    }

    mutating func endTransform() -> ToppingTransformDraft {
        let committed = self
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

/// SwiftUI 제스처로는 이슈와 버그가 많아서 UIKit을 사용합니다.
/// 이동·확대·회전을 동시에 받는 배치 제스처 면 (인스타그램식 pinch+pan).
///
/// SwiftUI 제스처 조합으로는 두 손가락 centroid 이동을 표현할 수 없다 — `DragGesture` 는
/// 첫 손가락만 추적해서, 핀치와 동시에 두면 손가락을 벌릴 때 토핑이 첫 손가락을 따라 튄다.
/// 핀치 중 드래그를 죽이는 우회는 핀치 시작 시점까지의 이동을 날려 버렸다(위치 스냅백).
/// 그래서 이 레이어만 UIKit 인식기를 쓴다 (`ToppingCanvasGestureOverlay` 와 같은 사정).
///
/// 델타는 window 좌표로 읽는다 — 이 면이 토핑을 따라 회전해도(C-305) 이동 방향이 뒤틀리지 않는다.
struct ToppingTransformGestureOverlay: UIViewRepresentable {
    var onTap: (() -> Void)?
    let onMove: (CGSize) -> Void
    let onMagnify: (Double) -> Void
    let onRotate: (Double) -> Void
    let onTransformEnded: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.overlay = self
        uiView.isUserInteractionEnabled = context.environment.isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(overlay: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var overlay: ToppingTransformGestureOverlay
        private var transformRecognizers: [UIGestureRecognizer] = []

        init(overlay: ToppingTransformGestureOverlay) {
            self.overlay = overlay
        }

        func attach(to view: UIView) {
            let move = UIPanGestureRecognizer(target: self, action: #selector(handleMove))
            move.maximumNumberOfTouches = 2

            let magnify = UIPinchGestureRecognizer(target: self, action: #selector(handleMagnify))
            let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate))

            transformRecognizers = [move, magnify, rotate]
            for recognizer in transformRecognizers {
                recognizer.delegate = self
                view.addGestureRecognizer(recognizer)
            }

            view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        }

        @objc private func handleMove(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                let translation = recognizer.translation(in: nil)
                overlay.onMove(CGSize(width: translation.x, height: translation.y))
                recognizer.setTranslation(.zero, in: nil)
            case .ended, .cancelled, .failed:
                commitIfTransformIdle()
            default:
                break
            }
        }

        @objc private func handleMagnify(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                overlay.onMagnify(Double(recognizer.scale))
                recognizer.scale = 1
            case .ended, .cancelled, .failed:
                commitIfTransformIdle()
            default:
                break
            }
        }

        @objc private func handleRotate(_ recognizer: UIRotationGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                overlay.onRotate(Double(recognizer.rotation) * 180 / .pi)
                recognizer.rotation = 0
            case .ended, .cancelled, .failed:
                commitIfTransformIdle()
            default:
                break
            }
        }

        @objc private func handleTap() {
            overlay.onTap?()
        }

        /// 세 인식기 중 마지막 하나가 끝나는 시점에 한 번만 커밋한다.
        private func commitIfTransformIdle() {
            let isTransforming = transformRecognizers.contains {
                $0.state == .began || $0.state == .changed
            }
            guard !isTransforming else { return }
            overlay.onTransformEnded()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            other.view === gestureRecognizer.view && !(other is UITapGestureRecognizer)
        }
    }
}
