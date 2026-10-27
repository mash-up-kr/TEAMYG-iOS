//
//  TextToppingStore.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/14/26.
//

import CanvasDomain
import Common
import CoreGraphics
import Observation
import UIComponent

/// C-106 텍스트 입력·배치. 입력(키보드 ↑)과 배치(C-106-Arrange, 키보드 ↓) 두 상태를 오간다.
/// 스펙: `docs/superpowers/specs/2026-10-14-canvas-text-requirements.md`
@Observable @MainActor
final class TextToppingStore: MVIStore {
    private(set) var state: State

    @ObservationIgnored let eventChannel = EventChannel<Event>()
    let dependencies: Dependencies

    init(state: State = State(), dependencies: Dependencies) {
        self.state = state
        self.dependencies = dependencies
    }

    func eventStream() -> AsyncStream<Event> {
        eventChannel.stream()
    }

    // swiftlint:disable:next cyclomatic_complexity
    func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            dependencies.logAnalyticsEvent(.screenView(.canvasText))
        case .textChanged(let text):
            // 쌓은 텍스트의 내용은 고칠 수 없다 (제품 정책) — 입력창도 막지만 여기서 한 번 더 지킨다.
            guard state.editing == nil else { return }
            state.text = TextToppingLayout.limited(text)
            refitFontSize()
        case .canvasResized(let canvasSize):
            state.canvasSize = canvasSize
            refitFontSize()
        case .textAreaResized(let height):
            // 키보드가 내려가 입력 영역이 커져도 박스를 다시 놓지 않는다 — 닫는 중엔 페이드아웃 중에 박스가 내려가며 커져 보였고,
            // 배치에서 받아 두면 다시 입력으로 들어갈 때 키보드가 아직 안 올라온 높이로 박스를 놓았다.
            guard state.phase == .input, !state.isDismissing else { return }
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
        case .confirmTapped, .editingEnded:
            finishInput()
        case .transformBegan:
            // 새 텍스트: 손가락 아래에 있는 입력 자리에서 이어 움직인다 — 이전 배치 자리로 돌아가면 손가락에서 떨어져 튀었다.
            // 수정: 쌓아 둔 자리·배율로 돌아가 이어 간다 — 입력 자리(배율 1)에서 이어 가면 쌓아 둔 크기를 잃는다.
            finishInput(placement: state.editing == nil ? state.inputPlacement : nil)
        case .placementCommitted(let draft):
            guard let placement = state.placement else { return }
            state.placement = draft.applied(to: placement, in: state.canvasSize)
        case .arrangedTextTapped:
            state.phase = .input
        case .deleteTapped:
            // 새 텍스트는 지우면 남는 게 없어 바로 닫는다. 쌓아 둔 텍스트는 지운 표시만 하고 `[캔버스에 쌓기]` 때 반영한다.
            if state.editing == nil { requestDismiss() } else { state.isDeleted = true }
        case .closeTapped:
            if state.hasChanges { state.showsExitPopup = true } else { requestDismiss() }
        case .exitPopupVisibilityChanged(let isPresented):
            state.showsExitPopup = isPresented
        case .discardTapped:
            requestDismiss()
        case .stackTapped:
            dependencies.logAnalyticsEvent(.canvasTextStackTapped(groupID: String(dependencies.groupID)))
            if let editing = state.editing { saveEdit(of: editing) } else { saveText() }
        }
    }

    /// 키보드를 내리는 모든 경로(✓·박스 밖 탭·끌기·핀치·시스템)가 여기로 모인다.
    /// 이 순간의 줄바꿈과 글자 크기를 고정한다 — 배치에서 입력 영역이 커져도 다시 계산하지 않는다.
    /// `placement` 가 없으면 이전 배치 자리로, 처음이면 입력 중 보이던 자리로 놓는다.
    private func finishInput(placement: ToppingPlacement? = nil) {
        guard state.phase == .input else { return }
        state.isColorPopoverPresented = false

        guard !state.isBlank else {
            // 새 텍스트를 빈 채로 내리면 만들 것이 없다 — 변경이 없으니 팝업 없이 닫는다.
            requestDismiss()
            return
        }

        // 쌓아 둔 텍스트는 받은 개행 그대로 둔다 — 글자 크기가 기본값으로 돌아와 있어 다시 감싸면 줄이 바뀐다.
        if state.editing == nil {
            state.arrangedText = TextToppingLayout
                .lines(of: state.text, fontSize: state.displayFontSize, maxWidth: state.canvasSize.width)
                .joined(separator: "\n")
        }
        // 새 텍스트의 "원래 자리" 는 입력 중 보이던 자리 — 키보드가 내려가며 튀지 않는다.
        state.placement = placement ?? state.placement ?? state.inputPlacement
        state.phase = .arrange
    }

    /// 배치한 텍스트를 서버에 쌓고, 성공하면 닫는다 — 닫히면 캔버스가 다시 조회해 새 텍스트를 그린다.
    private func saveText() {
        // 이미 저장 중이면 조용히 무시한다 — 진행 중인 저장을 실패로 보고하면 안 된다.
        guard !state.isSaving else { return }
        guard let draft = state.textDraft(zOrder: dependencies.nextZOrder),
              let parfaitID = dependencies.parfaitID
        else {
            eventChannel.send(.saveFailed)
            return
        }

        save { dependencies in
            let placed = try await dependencies.toppingUseCase.placeText(
                draft,
                groupID: dependencies.groupID,
                parfaitID: parfaitID
            )
            return .saved(CanvasStore.CanvasText(placed))
        }
    }

    /// 저장 중엔 화면을 막고, 성공하면 캔버스에 바로 반영한 뒤 닫는다.
    func save(_ operation: @escaping @Sendable (Dependencies) async throws -> TextToppingChange) {
        state.isSaving = true
        Task { [weak self, dependencies] in
            do {
                let change = try await operation(dependencies)
                guard let self else { return }
                state.isSaving = false
                dependencies.onChange(change)
                requestDismiss()
            } catch {
                guard let self else { return }
                state.isSaving = false
                eventChannel.send(.saveFailed)
            }
        }
    }

    func requestDismiss() {
        guard !state.isDismissing else { return }
        state.isDismissing = true
        eventChannel.send(.dismissRequested)
    }

    private func refitFontSize() {
        // 쌓아 둔 텍스트는 크기가 이미 `scale` 에 담겨 있다 — 다시 줄이면 이중으로 작아진다.
        guard state.editing == nil, state.phase == .input, state.canvasScale > 0, state.textAreaHeight > 0
        else { return }

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
        let padding = state.displayType.hasFill ? TextToppingLayout.boxPadding(fontSize: fontSize).vertical : 0
        let border = state.displayType.hasStroke ? TextToppingLayout.borderWidth(fontSize: fontSize) : 0
        return (padding + border) * 2
    }
}

extension TextToppingStore {
    struct State: Equatable {
        var phase = Phase.input
        var text = ""
        var color = TextToppingColor.white
        var type = TextToppingType.plain
        var alignment = PlacedTextAlignment.center
        var isColorPopoverPresented = false
        var showsExitPopup = false
        /// 닫는 중 — 편집을 끄고(키보드 내림) 화면 배치를 고정한다. 닫기 요청은 한 번만 보낸다.
        var isDismissing = false
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
        var isSaving = false
        /// 쌓아 둔 내 텍스트를 고치는 중이면 그 원래 값.
        var editing: TextToppingEditing?
        /// 고치는 중 모서리 X 로 지운 표시 — `[캔버스에 쌓기]` 때 서버에서 지운다.
        var isDeleted = false

        var isBlank: Bool {
            TextToppingLayout.isBlank(text)
        }

        /// 캔버스에 그릴 타입 — 입력한 글이 없으면 고른 타입과 무관하게 `plain` (플레이스홀더엔 배경·테두리 없음).
        /// 툴바 아이콘은 고른 타입(`type`)을 그대로 보여준다.
        var displayType: TextToppingType {
            isBlank ? .plain : type
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

        /// 서버에 보낼 텍스트. 배치를 마친(키보드를 한 번 내린) 뒤에만 만들 수 있다.
        /// 글자 크기는 기본 크기 × `scale` 로만 전하므로 자동 축소분을 핀치 배율에 합친다.
        func textDraft(zOrder: Int) -> TextDraft? {
            guard let placement, !isBlank else { return nil }
            return TextDraft(
                text: arrangedText,
                placement: ToppingPlacementValues(
                    positionX: placement.positionX,
                    positionY: placement.positionY,
                    positionZ: zOrder,
                    scale: placement.scale * Double(designFontSize) / PlacedText.baseFontSize,
                    rotation: placement.rotationDegrees
                ),
                colorHex: color.textHex,
                isFill: type.hasFill,
                isStroke: type.hasStroke,
                alignment: alignment
            )
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
        case saveFailed
    }

    struct Dependencies: Sendable {
        let groupID: Int
        let parfaitID: Int?
        /// 새 텍스트를 맨 위(이미지·텍스트 전체)에 얹을 `positionZ`. 화면을 연 시점의 캔버스 기준.
        let nextZOrder: Int
        let toppingUseCase: any ToppingUseCase
        /// 저장을 마친 결과를 캔버스에 바로 넘긴다.
        let onChange: @MainActor @Sendable (TextToppingChange) -> Void
        let logAnalyticsEvent: AnalyticsEventLogger
    }

    enum Intent {
        case screenAppeared
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
