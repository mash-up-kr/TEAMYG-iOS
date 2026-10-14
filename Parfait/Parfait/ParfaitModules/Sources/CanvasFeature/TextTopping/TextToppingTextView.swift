//
//  TextToppingTextView.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/14/26.
//

import SwiftUI
import UIKit

/// 캔버스 텍스트 박스. 입력·배치 두 상태에서 **같은 인스턴스**를 쓴다 — 입력 중 시작한 끌기·핀치가 배치로 넘어가도 끊기지 않게.
///
/// 이동·확대·회전은 `ToppingTransformGestureOverlay` 와 같은 사정으로 UIKit 인식기를 텍스트 뷰에 직접 단다.
/// 확대·회전의 축은 박스 중심이다 (`pivotOffset: .zero`).
struct TextToppingTextView: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let color: UIColor
    let alignment: NSTextAlignment
    /// 프레임 안 글자 영역 여백 (textContainerInset). 줄바꿈 너비 = 프레임 너비 − 좌우 여백.
    let textInset: UIEdgeInsets
    /// true: 편집 가능 + first responder, false: 편집 불가 + resign
    let isEditing: Bool
    /// false 면 끌기·핀치·회전 인식 안 함 (빈 내용)
    let isTransformEnabled: Bool
    /// 진행 중 끌기·핀치·회전 값 (커밋 전 미리보기)
    @Binding var draft: ToppingTransformDraft
    let onTextChange: (String) -> Void
    /// 시스템이 키보드를 내린 경우 등 편집이 끝났을 때. `isEditing = false` 로 내린 경우엔 부르지 않는다.
    let onEditingEnd: () -> Void
    /// 끌기·핀치·회전이 시작되는 순간 (키보드 내림·배치 전환 트리거)
    let onTransformBegin: () -> Void
    /// 모든 변형 제스처가 끝났을 때 1회. `onTransformBegin` 과 항상 짝을 이룬다 (변화량이 없어도 호출).
    let onTransformCommit: (ToppingTransformDraft) -> Void

    func makeUIView(context: Context) -> UITextView {
        // NSLayoutManager 로 측정하는 `TextToppingLayout` 과 줄바꿈이 같아야 해서 TextKit 1 을 쓴다.
        let textView = UITextView(usingTextLayoutManager: false)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        // 줄바꿈 너비를 따로 지정하지 않고 프레임에서 따라가게 한다 — 따로 두면 입력으로 프레임이 바뀔 때
        // 내부 레이아웃이 어긋난 채 그려졌다가 다른 갱신 때 뒤늦게 바로잡혀 글자가 튀어 보였다.
        textView.textContainer.widthTracksTextView = true
        context.coordinator.attach(to: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.setTransformEnabled(isTransformEnabled)

        if textView.textContainerInset != textInset {
            textView.textContainerInset = textInset
        }

        // 한글 조합 중(marked text)에 attributedText 를 갈아 끼우면 조합이 깨진다 → 조합이 끝난 뒤 반영.
        let style = TextToppingAppliedStyle(fontSize: fontSize, color: color, alignment: alignment)
        if textView.markedTextRange == nil, textView.text != text || coordinator.appliedStyle != style {
            let attributes = TextToppingLayout.attributes(
                fontSize: fontSize,
                color: color,
                alignment: alignment
            )
            let selectedRange = textView.selectedRange
            textView.attributedText = NSAttributedString(string: text, attributes: attributes)
            textView.typingAttributes = attributes
            textView.tintColor = color
            let length = textView.attributedText.length
            let location = min(selectedRange.location, length)
            textView.selectedRange = NSRange(
                location: location,
                length: min(selectedRange.length, length - location)
            )
            coordinator.appliedStyle = style
        }

        textView.isEditable = isEditing
        textView.isSelectable = isEditing
        // 뷰 업데이트 도중 responder 를 바꾸면 delegate 콜백이 상태를 건드리므로 다음 런루프로 미룬다.
        if isEditing != textView.isFirstResponder {
            DispatchQueue.main.async { [weak textView, weak coordinator] in
                guard let textView, let coordinator else { return }
                if coordinator.parent.isEditing, !textView.isFirstResponder {
                    textView.becomeFirstResponder()
                } else if !coordinator.parent.isEditing, textView.isFirstResponder {
                    textView.resignFirstResponder()
                }
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        // 바깥에서 프레임을 직접 잡아 준다.
        proposal.replacingUnspecifiedDimensions()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: TextToppingTextView
        fileprivate var appliedStyle: TextToppingAppliedStyle?
        private var draft = ToppingTransformDraft()
        private var isTransforming = false
        private var transformRecognizers: [UIGestureRecognizer] = []

        init(parent: TextToppingTextView) {
            self.parent = parent
        }

        func attach(to textView: UITextView) {
            let move = UIPanGestureRecognizer(target: self, action: #selector(handleMove))
            move.maximumNumberOfTouches = 2

            let magnify = UIPinchGestureRecognizer(target: self, action: #selector(handleMagnify))
            let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate))

            transformRecognizers = [move, magnify, rotate]
            for recognizer in transformRecognizers {
                recognizer.delegate = self
                textView.addGestureRecognizer(recognizer)
            }
        }

        func setTransformEnabled(_ isEnabled: Bool) {
            for recognizer in transformRecognizers where recognizer.isEnabled != isEnabled {
                recognizer.isEnabled = isEnabled
            }
        }

        // MARK: - 입력

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            // 조합 중 입력은 막지 않는다 — 조합이 끝난 뒤 `textViewDidChange` 에서 자른다.
            guard textView.markedTextRange == nil, !replacement.isEmpty else { return true }

            let currentText = (textView.text ?? "") as NSString
            let keptCount = (currentText as String).count - currentText.substring(with: range).count
            let allowedCount = max(TextToppingLayout.characterLimit - keptCount, 0)
            guard replacement.count > allowedCount else { return true }

            // 넘치는 붙여넣기는 넣는 글의 앞부분만 넣는다 — 커서 뒤에 있던 기존 글은 지우지 않는다.
            let allowedReplacement = String(replacement.prefix(allowedCount))
            textView.textStorage.replaceCharacters(
                in: range,
                with: NSAttributedString(string: allowedReplacement, attributes: textView.typingAttributes)
            )
            let caretLocation = range.location + (allowedReplacement as NSString).length
            textView.selectedRange = NSRange(location: caretLocation, length: 0)
            parent.onTextChange(textView.text ?? "")
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            let currentText = textView.text ?? ""
            // 한글 조합으로 넘친 경우 — 조합이 끝난 뒤 앞 100자만 남긴다.
            if textView.markedTextRange == nil, currentText.count > TextToppingLayout.characterLimit {
                textView.attributedText = NSAttributedString(
                    string: TextToppingLayout.limited(currentText),
                    attributes: textView.typingAttributes
                )
                textView.selectedRange = NSRange(location: textView.attributedText.length, length: 0)
            }
            parent.onTextChange(textView.text ?? "")
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            // `isEditing = false` 로 우리가 내린 경우는 이미 바깥이 알고 있다.
            guard parent.isEditing else { return }
            parent.onEditingEnd()
        }

        // MARK: - 변형 제스처

        @objc private func handleMove(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                beginTransformIfNeeded()
            case .changed:
                // 박스 자체가 확대·회전된 채 그려지므로 window 좌표로 받아야 손가락과 일치한다.
                let translation = recognizer.translation(in: nil)
                draft.move(by: CGSize(width: translation.x, height: translation.y))
                recognizer.setTranslation(.zero, in: nil)
                parent.draft = draft
            case .ended, .cancelled, .failed:
                commitIfTransformIdle()
            default:
                break
            }
        }

        @objc private func handleMagnify(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                beginTransformIfNeeded()
            case .changed:
                draft.magnify(by: Double(recognizer.scale), pivotOffset: .zero)
                recognizer.scale = 1
                parent.draft = draft
            case .ended, .cancelled, .failed:
                commitIfTransformIdle()
            default:
                break
            }
        }

        @objc private func handleRotate(_ recognizer: UIRotationGestureRecognizer) {
            switch recognizer.state {
            case .began:
                beginTransformIfNeeded()
            case .changed:
                draft.rotate(byDegrees: Double(recognizer.rotation) * 180 / .pi, pivotOffset: .zero)
                recognizer.rotation = 0
                parent.draft = draft
            case .ended, .cancelled, .failed:
                commitIfTransformIdle()
            default:
                break
            }
        }

        private func beginTransformIfNeeded() {
            guard !isTransforming else { return }
            isTransforming = true
            parent.onTransformBegin()
        }

        /// 세 인식기 중 마지막 하나가 끝나는 시점에 한 번만 커밋한다.
        private func commitIfTransformIdle() {
            let isRecognizing = transformRecognizers.contains {
                $0.state == .began || $0.state == .changed
            }
            guard isTransforming, !isRecognizing else { return }

            isTransforming = false
            let committed = draft.endTransform()
            parent.draft = draft
            parent.onTransformCommit(committed)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer is UIPanGestureRecognizer, let textView = gestureRecognizer.view else {
                return true
            }
            // 길게 눌러 선택·돋보기·선택 핸들 끌기 등 시스템 텍스트 인식기가 이미 터치를 잡았으면 끌기로 뺏지 않는다.
            // ponytail: "텍스트 뷰에 붙은 우리 것 아닌 인식기가 began/changed 면 시스템이 쓰는 중" 으로 본다.
            // 이동 시작 거리는 UIPan 기본 hysteresis(약 10pt)에 맡긴다 — shouldBegin 은 한 번 거절하면
            // 그 터치 내내 실패라서, 여기서 거리를 다시 재면 기본값보다 짧게 움직인 끌기가 통째로 죽는다.
            let isSystemInteracting = textView.gestureRecognizers?.contains { recognizer in
                !transformRecognizers.contains(recognizer)
                    && (recognizer.state == .began || recognizer.state == .changed)
            } ?? false
            return !isSystemInteracting
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            transformRecognizers.contains(gestureRecognizer) && transformRecognizers.contains(other)
        }
    }
}

/// 마지막으로 텍스트 뷰에 반영한 글자 스타일. 바뀌었을 때만 attributedText 를 다시 쓰려고 들고 있다.
private struct TextToppingAppliedStyle: Equatable {
    let fontSize: CGFloat
    let color: UIColor
    let alignment: NSTextAlignment
}
