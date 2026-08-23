//
//  ToppingCanvasGestureOverlay.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import SwiftUI
import UIKit

/// 한 손가락은 브러시, 두 손가락은 pinch/pan 으로 갈라야 한다 (`topping_ui.md` §6.3).
/// SwiftUI 제스처로는 "두 손가락일 때만" 을 표현할 수 없어 이 레이어만 UIKit 인식기를 쓴다.
struct ToppingCanvasGestureOverlay: UIViewRepresentable {
    let onBrushBegan: (CGPoint) -> Void
    let onBrushMoved: (CGPoint) -> Void
    let onBrushEnded: () -> Void
    let onBrushCancelled: () -> Void
    let onMagnify: (CGFloat) -> Void
    let onPan: (CGSize) -> Void
    let onTransformEnded: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let brush = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleBrush)
        )
        brush.minimumNumberOfTouches = 1
        brush.maximumNumberOfTouches = 1
        brush.delegate = context.coordinator

        let magnify = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMagnify)
        )
        magnify.delegate = context.coordinator

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan)
        )
        pan.minimumNumberOfTouches = 2
        pan.delegate = context.coordinator

        // `require(toFail:)` 로 묶으면 pinch 가 실패할 때까지 pan 이벤트가 통째로 지연돼
        // 스트로크가 점 하나로 뭉개진다. 대신 pinch/두 손가락 pan 이 시작될 때 스트로크를 끊는다.
        for recognizer in [brush, magnify, pan] {
            view.addGestureRecognizer(recognizer)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.overlay = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(overlay: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var overlay: ToppingCanvasGestureOverlay

        init(overlay: ToppingCanvasGestureOverlay) {
            self.overlay = overlay
        }

        @objc func handleBrush(_ recognizer: UIPanGestureRecognizer) {
            let location = recognizer.location(in: recognizer.view)
            switch recognizer.state {
            case .began:
                overlay.onBrushBegan(location)
            case .changed:
                overlay.onBrushMoved(location)
            case .ended:
                overlay.onBrushEnded()
            case .cancelled, .failed:
                overlay.onBrushCancelled()
            default:
                break
            }
        }

        @objc func handleMagnify(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                overlay.onBrushEnded()
            case .changed:
                overlay.onMagnify(recognizer.scale)
                recognizer.scale = 1
            case .ended, .cancelled, .failed:
                overlay.onTransformEnded()
            default:
                break
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                overlay.onBrushEnded()
            case .changed:
                let translation = recognizer.translation(in: recognizer.view)
                overlay.onPan(CGSize(width: translation.x, height: translation.y))
                recognizer.setTranslation(.zero, in: recognizer.view)
            case .ended, .cancelled, .failed:
                overlay.onTransformEnded()
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            gestureRecognizer is UIPinchGestureRecognizer || other is UIPinchGestureRecognizer
        }
    }
}
