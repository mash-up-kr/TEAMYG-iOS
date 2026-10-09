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
struct ToppingTransformDraft: Equatable {
    private(set) var translation: CGSize = .zero
    private(set) var scaleFactor: Double = 1
    private(set) var rotationDegrees: Double = 0

    func applied(to placement: ToppingPlacement, in canvasSize: CGSize) -> ToppingPlacement {
        placement
            .magnified(by: scaleFactor)
            .moved(by: translation, in: canvasSize)
            .rotated(by: rotationDegrees)
    }

    mutating func move(by delta: CGSize) {
        translation.width += delta.width
        translation.height += delta.height
    }

    mutating func magnify(by factor: Double, pivotOffset: CGSize) {
        scaleFactor *= factor
        translation.width += pivotOffset.width * CGFloat(factor - 1)
        translation.height += pivotOffset.height * CGFloat(factor - 1)
    }

    mutating func rotate(byDegrees degrees: Double, pivotOffset: CGSize) {
        rotationDegrees += degrees

        let radians = CGFloat(degrees * .pi / 180)
        let rotatedOffset = CGSize(
            width: pivotOffset.width * cos(radians) - pivotOffset.height * sin(radians),
            height: pivotOffset.width * sin(radians) + pivotOffset.height * cos(radians)
        )
        translation.width += rotatedOffset.width - pivotOffset.width
        translation.height += rotatedOffset.height - pivotOffset.height
    }

    /// 유일한 커밋 지점. 커밋 값은 프리뷰와 같은 `applied(to:in:)` 로
    /// 반영하므로 프리뷰와 확정 결과가 구조적으로 일치한다.
    mutating func endTransform() -> ToppingTransformDraft {
        let committed = self
        resetTransform()
        return committed
    }

    private mutating func resetTransform() {
        translation = .zero
        scaleFactor = 1
        rotationDegrees = 0
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
/// 캔버스 전체를 덮어야 한다 — 토핑 크기로 자르면 두 번째 손가락이 면 밖에 떨어져 핀치가 깨진다.
/// 확대·회전의 축은 두 손가락 중점이다. `placementCenter` 는 이 면 좌표계에서 드래프트 적용 전
/// 토핑 중심이고, `nil` 이면 탭만 받는다.
struct ToppingTransformGestureOverlay: UIViewRepresentable {
    @Binding var draft: ToppingTransformDraft
    let placementCenter: CGPoint?
    var onTouchBegan: (() -> Void)?
    var onSwallowedTouch: (() -> Void)?
    var onTap: ((CGPoint) -> Void)?
    let onCommit: (ToppingTransformDraft) -> Void

    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        view.backgroundColor = .clear
        context.coordinator.attach(to: view)
        view.cancelRecognition = { [coordinator = context.coordinator] in
            coordinator.cancelRecognition()
        }
        return view
    }

    func updateUIView(_ uiView: Surface, context: Context) {
        context.coordinator.overlay = self
        context.coordinator.setTransformEnabled(placementCenter != nil)
        uiView.onTouchBegan = onTouchBegan
        uiView.onSwallowedTouch = onSwallowedTouch
        uiView.isUserInteractionEnabled = context.environment.isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(overlay: self)
    }

    final class Surface: UIView {
        var onTouchBegan: (() -> Void)?
        var onSwallowedTouch: (() -> Void)?
        var cancelRecognition: (() -> Void)?
        private var isSwallowingTouches = false

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            onTouchBegan?()
            if let onSwallowedTouch {
                isSwallowingTouches = true
                onSwallowedTouch()
            }
            if isSwallowingTouches {
                cancelRecognition?()
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            stopSwallowingIfTouchesFinished(event)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event)
            stopSwallowingIfTouchesFinished(event)
        }

        private func stopSwallowingIfTouchesFinished(_ event: UIEvent?) {
            let hasActiveTouch = event?.allTouches?.contains {
                $0.phase != .ended && $0.phase != .cancelled
            } ?? false
            if !hasActiveTouch {
                isSwallowingTouches = false
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var overlay: ToppingTransformGestureOverlay
        private var draft = ToppingTransformDraft()
        private var transformRecognizers: [UIGestureRecognizer] = []
        private var recognizers: [UIGestureRecognizer] = []

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

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            view.addGestureRecognizer(tap)
            recognizers = transformRecognizers + [tap]
        }

        func cancelRecognition() {
            for recognizer in recognizers where recognizer.isEnabled {
                recognizer.isEnabled = false
                recognizer.isEnabled = true
            }
        }

        func setTransformEnabled(_ isEnabled: Bool) {
            for recognizer in transformRecognizers where recognizer.isEnabled != isEnabled {
                recognizer.isEnabled = isEnabled
            }
        }

        @objc private func handleMove(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                let translation = recognizer.translation(in: recognizer.view)
                draft.move(by: CGSize(width: translation.x, height: translation.y))
                recognizer.setTranslation(.zero, in: recognizer.view)
                overlay.draft = draft
            case .ended, .cancelled, .failed:
                commitIfTransformIdle()
            default:
                break
            }
        }

        @objc private func handleMagnify(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                draft.magnify(by: Double(recognizer.scale), pivotOffset: pivotOffset(for: recognizer))
                recognizer.scale = 1
                overlay.draft = draft
            case .ended, .cancelled, .failed:
                commitIfTransformIdle()
            default:
                break
            }
        }

        @objc private func handleRotate(_ recognizer: UIRotationGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                draft.rotate(
                    byDegrees: Double(recognizer.rotation) * 180 / .pi,
                    pivotOffset: pivotOffset(for: recognizer)
                )
                recognizer.rotation = 0
                overlay.draft = draft
            case .ended, .cancelled, .failed:
                commitIfTransformIdle()
            default:
                break
            }
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            overlay.onTap?(recognizer.location(in: recognizer.view))
        }

        private func pivotOffset(for recognizer: UIGestureRecognizer) -> CGSize {
            guard let placementCenter = overlay.placementCenter else { return .zero }

            let pivot = recognizer.location(in: recognizer.view)
            return CGSize(
                width: placementCenter.x + draft.translation.width - pivot.x,
                height: placementCenter.y + draft.translation.height - pivot.y
            )
        }

        /// 세 인식기 중 마지막 하나가 끝나는 시점에 한 번만 커밋한다.
        private func commitIfTransformIdle() {
            let isTransforming = transformRecognizers.contains {
                $0.state == .began || $0.state == .changed
            }
            guard !isTransforming, draft != ToppingTransformDraft() else { return }

            let committed = draft.endTransform()
            overlay.draft = draft
            overlay.onCommit(committed)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            other.view === gestureRecognizer.view && !(other is UITapGestureRecognizer)
        }
    }
}
