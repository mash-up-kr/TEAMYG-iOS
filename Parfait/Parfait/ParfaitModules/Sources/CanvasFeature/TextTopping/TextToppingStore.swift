//
//  TextToppingStore.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/14/26.
//

import CoreGraphics
import Observation
import UIComponent

/// C-106 텍스트 입력·배치. 입력(키보드 ↑)과 배치(C-106-Arrange, 키보드 ↓) 두 상태를 오간다.
/// 스펙: `docs/superpowers/specs/2026-10-14-canvas-text-requirements.md`
@Observable @MainActor
final class TextToppingStore: MVIStore {
    private(set) var state: State

    @ObservationIgnored private let eventChannel = EventChannel<Event>()
    /// 닫히는 동안 키보드가 내려가며 `editingEnded` 가 한 번 더 들어온다 — 닫기 요청은 한 번만 보낸다.
    @ObservationIgnored private var isDismissRequested = false

    init(state: State) {
        self.state = state
    }

    func eventStream() -> AsyncStream<Event> {
        eventChannel.stream()
    }

    // swiftlint:disable:next cyclomatic_complexity
    func send(_ intent: Intent) {
        switch intent {
        case .textChanged(let text):
            state.text = TextToppingLayout.limited(text)
            refitFontSize()
        case .canvasResized(let canvasSize):
            state.canvasSize = canvasSize
            refitFontSize()
        case .textAreaResized(let height):
            state.textAreaHeight = height
            refitFontSize()
        case .colorButtonTapped:
            state.isColorPopoverPresented.toggle()
        case .colorSelected(let color):
            state.color = color
        case .typeButtonTapped:
            state.type = state.type.next
            refitFontSize()
        case .alignmentButtonTapped:
            state.alignment = state.alignment.next
        case .outsideTapped:
            // 열린 것부터 하나씩 닫는다 — 팝오버가 열려 있으면 이 탭은 팝오버만 닫는다.
            guard !state.isColorPopoverPresented else {
                state.isColorPopoverPresented = false
                return
            }
            finishInput()
        case .confirmTapped, .editingEnded, .transformBegan:
            finishInput()
        case .placementCommitted(let draft):
            guard let placement = state.placement else { return }
            state.placement = draft.applied(to: placement, in: state.canvasSize)
        case .arrangedTextTapped:
            state.phase = .input
        case .deleteTapped:
            // ponytail: 새 텍스트만 다루는 1차 범위 — 지우면 남는 게 없어 바로 닫는다. 수정 흐름(3차)에서 삭제 표시로 바꾼다.
            requestDismiss()
        case .closeTapped:
            state.showsExitPopup = true
        case .exitPopupVisibilityChanged(let isPresented):
            state.showsExitPopup = isPresented
        case .discardTapped:
            requestDismiss()
        case .stackTapped:
            // ⚠️ 2차: 서버 텍스트 API 가 생기면 여기서 저장한다.
            break
        }
    }

    /// 키보드를 내리는 모든 경로(✓·박스 밖 탭·끌기·핀치·시스템)가 여기로 모인다.
    /// 이 순간의 줄바꿈과 글자 크기를 고정한다 — 배치에서 입력 영역이 커져도 다시 계산하지 않는다.
    private func finishInput() {
        guard state.phase == .input else { return }
        state.isColorPopoverPresented = false

        guard !state.isBlank else {
            // 새 텍스트를 빈 채로 내리면 만들 것이 없다 — 변경이 없으니 팝업 없이 닫는다.
            requestDismiss()
            return
        }

        state.arrangedText = TextToppingLayout
            .lines(of: state.text, fontSize: state.displayFontSize, maxWidth: state.canvasSize.width)
            .joined(separator: "\n")
        // 새 텍스트의 "원래 자리" 는 입력 중 보이던 자리 — 키보드가 내려가며 튀지 않는다.
        state.placement = state.placement ?? state.inputPlacement
        state.phase = .arrange
    }

    private func requestDismiss() {
        guard !isDismissRequested else { return }
        isDismissRequested = true
        eventChannel.send(.dismissRequested)
    }

    private func refitFontSize() {
        guard state.phase == .input, state.canvasScale > 0, state.textAreaHeight > 0 else { return }

        let maxFontSize = TextToppingLayout.maximumFontSize * state.canvasScale
        let fittingFontSize = TextToppingLayout.fittingFontSize(
            for: state.measuredText,
            maxFontSize: maxFontSize,
            maxWidth: state.canvasSize.width,
            maxHeight: state.textAreaHeight - boxVerticalExtra(fontSize: maxFontSize)
        )
        state.designFontSize = fittingFontSize / state.canvasScale
    }

    /// 네모배경 상하 여백 + 바깥 테두리 — 글자뿐 아니라 박스 전체가 입력 영역에 들어가야 한다.
    /// ponytail: 최대 글자 크기 기준으로 빼서 축소된 글자에선 몇 pt 여유가 남는다. 글자 크기마다 빼려면 이진 탐색 안으로 넣는다.
    private func boxVerticalExtra(fontSize: CGFloat) -> CGFloat {
        let padding = state.type.hasFill ? TextToppingLayout.boxPadding(fontSize: fontSize).vertical : 0
        let border = state.type.hasStroke ? TextToppingLayout.borderWidth(fontSize: fontSize) : 0
        return (padding + border) * 2
    }
}

extension TextToppingStore {
    struct State: Equatable {
        var phase = Phase.input
        var text = ""
        var color = TextToppingColor.white
        var type = TextToppingType.plain
        var alignment = TextToppingAlignment.center
        var isColorPopoverPresented = false
        var showsExitPopup = false
        /// 화면 pt. 자동 크기 계산과 배치 좌표의 기준.
        var canvasSize: CGSize = .zero
        /// 캔버스 상단 ~ 툴바 위. 키보드·추천어 줄 높이에 따라 바뀐다 (화면 pt).
        var textAreaHeight: CGFloat = 0
        /// 디자인 pt (캔버스 너비 335 기준). 입력 중엔 자동 크기, 배치에선 키보드를 내린 순간 값으로 고정.
        var designFontSize = TextToppingLayout.maximumFontSize
        /// 배치에서 그릴 텍스트 — 키보드를 내린 순간의 화면 줄바꿈을 개행으로 박아 둔다. 다시 줄바꿈하지 않는다.
        var arrangedText = ""
        /// 배치 위치·핀치 배율·회전. 처음 키보드를 내릴 때 정해진다.
        var placement: ToppingPlacement?

        var isBlank: Bool {
            TextToppingLayout.isBlank(text)
        }

        /// 비어 있으면 플레이스홀더 크기로 박스를 잡는다.
        var measuredText: String {
            text.isEmpty ? TextToppingLayout.placeholder : text
        }

        /// 디자인 pt → 화면 pt 배율.
        var canvasScale: CGFloat {
            canvasSize.width / TextToppingLayout.designCanvasWidth
        }

        /// 핀치 배율을 뺀 화면 pt 글자 크기.
        var displayFontSize: CGFloat {
            designFontSize * canvasScale
        }

        /// 입력 중 박스 자리 — 입력 영역 가운데, 배율 1, 회전 0 (수정 진입도 같은 형태로 보여준다).
        var inputPlacement: ToppingPlacement {
            guard canvasSize.height > 0 else { return ToppingPlacement() }
            return ToppingPlacement(positionX: 0.5, positionY: Double(textAreaHeight / 2 / canvasSize.height))
        }

        var displayPlacement: ToppingPlacement {
            switch phase {
            case .input: inputPlacement
            case .arrange: placement ?? inputPlacement
            }
        }
    }

    enum Phase: Equatable {
        /// C-106 — 키보드 ↑, 자동 줄바꿈·자동 크기
        case input
        /// C-106-Arrange — 키보드 ↓, 줄바꿈·글자 크기 고정, 이동·핀치·회전
        case arrange
    }

    enum Event: Sendable {
        case dismissRequested
    }

    enum Intent {
        case textChanged(String)
        case canvasResized(CGSize)
        case textAreaResized(CGFloat)
        case colorButtonTapped
        case colorSelected(TextToppingColor)
        case typeButtonTapped
        case alignmentButtonTapped
        /// 텍스트 박스 밖 탭 (입력 영역·딤 포함)
        case outsideTapped
        case confirmTapped
        /// 시스템이 키보드를 내린 경우
        case editingEnded
        /// 입력 중 텍스트를 끌거나 핀치하기 시작함 — 키보드를 내리고 배치로 이어진다.
        case transformBegan
        case placementCommitted(ToppingTransformDraft)
        case arrangedTextTapped
        case deleteTapped
        case closeTapped
        case exitPopupVisibilityChanged(Bool)
        case discardTapped
        case stackTapped
    }
}
