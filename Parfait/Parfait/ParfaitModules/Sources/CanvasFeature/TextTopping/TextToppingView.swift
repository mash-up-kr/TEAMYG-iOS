//
//  TextToppingView.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/14/26.
//

import SwiftUI
import UIComponent

/// C-106 / C-106-Arrange.
///
/// 새 화면처럼 보이지 않게 배경에서 C-001 캔버스 자리(`canvasFrame`)만 뚫어 **뒤에 깔린 진짜 캔버스**가 그대로 보이게 하고,
/// 화면 전체를 페이드로 띄우고 내린다 — 캔버스는 제자리에 있고 헤더·딤·키보드만 바뀌는 것처럼 보인다.
/// 캔버스를 여기서 다시 그리면 배경·토핑 이미지를 새로 불러오는 동안 비거나 테두리가 달라 페이드 중에 잔상이 보였다.
/// 캔버스는 키보드에 밀리지 않고(C-001 이 키보드 안전 영역을 무시한다), 툴바만 키보드 위에 붙는다.
struct TextToppingView: View {
    private static var fadeAnimation: Animation { .easeInOut(duration: 0.2) }

    @State private var store: TextToppingStore
    /// 진행 중인 끌기·핀치·회전 — 커밋 전 미리보기라 뷰 로컬로만 든다 (`docs/mvi.md` 바인딩 절).
    @State private var draft = ToppingTransformDraft()
    /// 입력 중 텍스트 뷰에서 시작한 끌기·핀치가 이어지는 중인지.
    @State private var isTextViewTransforming = false
    @State private var toolbarMinY: CGFloat?
    @State private var isShown = false
    @Environment(\.dismiss) private var dismiss
    /// C-001 캔버스 패널의 화면 좌표 — 열릴 때 값으로 고정한다.
    @State private var canvasFrame: CGRect

    init(store: TextToppingStore, canvasFrame: CGRect) {
        _store = State(initialValue: store)
        _canvasFrame = State(initialValue: canvasFrame)
    }

    private var state: TextToppingStore.State { store.state }
    private var isInput: Bool { state.phase == .input }

    var body: some View {
        ZStack {
            // 안전 영역을 모두 무시해 이 층의 좌표가 곧 화면 좌표가 된다 — `canvasFrame` 을 그대로 쓴다.
            ZStack(alignment: .topLeading) {
                CanvasDotGridBackground()
                    .clipShape(ScreenExcludingCanvasShape(canvasFrame: canvasFrame), style: FillStyle(eoFill: true))

                if !isInput {
                    CanvasPanelShape()
                        .fill(Color.black25)
                        .frame(width: canvasFrame.width, height: canvasFrame.height)
                        .position(x: canvasFrame.midX, y: canvasFrame.midY)
                }

                if isInput {
                    // 박스 밖 탭 — 텍스트 박스와 툴바를 뺀 모든 곳. 닫기만 하고 아래로 넘기지 않는다.
                    Color.black50
                        .onTapGesture { store.send(.outsideTapped) }
                }

                textLayer
            }
            .ignoresSafeArea()

            if isInput {
                inputChrome
            }
        }
        .overlay(alignment: .top) {
            header
        }
        .overlay(alignment: .bottom) {
            if !isInput {
                YGButton("캔버스에 쌓기", variant: .large) { store.send(.stackTapped) }
                    .padding(.horizontal, .padding7)
                    .padding(.bottom, .padding1)
            }
        }
        .opacity(isShown ? 1 : 0)
        // `onAppear` 에서 올리면 첫 프레임이 그려지기 전이라 페이드 없이 한 번에 떴다 — 첫 프레임 뒤에 시작한다.
        .task {
            store.send(.screenAppeared)
            withAnimation(Self.fadeAnimation) { isShown = true }
        }
        .onChange(of: canvasFrame.size, initial: true) { _, size in
            store.send(.canvasResized(size))
        }
        .onChange(of: textAreaHeight, initial: true) { _, height in
            store.send(.textAreaResized(height))
        }
        .ygPopup(
            isPresented: store.binding(\.showsExitPopup, TextToppingStore.Intent.exitPopupVisibilityChanged),
            title: "텍스트 작성을 그만둘까요?",
            description: "지금까지 작성한 내용은 저장되지 않아요.\n정말 그만두시겠어요?",
            secondaryTitle: "그만두기",
            primaryTitle: "계속 작성",
            secondaryAction: { store.send(.discardTapped) }
        )
        .task {
            for await event in store.eventStream() {
                switch event {
                case .dismissRequested:
                    fadeOutAndDismiss()
                }
            }
        }
    }

    /// 들어올 때와 같이 페이드로 내리고, 시트 내림 애니메이션 없이 닫는다.
    private func fadeOutAndDismiss() {
        withAnimation(Self.fadeAnimation) {
            isShown = false
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { dismiss() }
        }
    }

    /// 캔버스 상단 ~ 툴바 위. 캔버스보다 길어지지 않는다.
    private var textAreaHeight: CGFloat {
        guard let toolbarMinY else { return canvasFrame.height }
        return min(max(toolbarMinY - canvasFrame.minY, 0), canvasFrame.height)
    }

    @ViewBuilder
    private var header: some View {
        if isInput {
            // 키보드가 올라와 있는 동안엔 나가기 없이 ✓ 만 둔다.
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 44, height: 44)
                Spacer(minLength: 0)
                Text("배치")
                    .suit(.body01Regular)
                    .foregroundStyle(.gray800)
                Spacer(minLength: 0)
                YGCircleButton(.icCheck, variant: .default) { store.send(.confirmTapped) }
            }
            .padding(.horizontal, .padding7)
            .padding(.top, .padding6)
        } else {
            YGFloatingBar(.title("배치"), onClose: { store.send(.closeTapped) })
        }
    }

    // MARK: - 텍스트

    private var textLayer: some View {
        let canvasSize = state.canvasSize
        let placement = draft.applied(to: state.displayPlacement, in: canvasSize)
        let fontSize = state.displayFontSize * CGFloat(placement.scale)
        let text = isInput ? state.text : state.arrangedText
        let textSize = TextToppingBox.textSize(
            of: text,
            fontSize: fontSize,
            // 배치에선 줄바꿈이 이미 개행으로 박혀 있어 제한 없이 잰다.
            wrapWidth: isInput ? canvasSize.width : .greatestFiniteMagnitude
        )
        let boxSize = TextToppingBox.boxSize(textSize: textSize, fontSize: fontSize, type: state.type)

        return ZStack {
            TextToppingBox(
                text: text,
                fontSize: fontSize,
                textSize: textSize,
                boxSize: boxSize,
                color: state.color,
                type: state.type,
                alignment: state.alignment,
                // 키보드는 이 값으로만 올리고 내린다 — 닫으며 따로 내리면 다음 뷰 갱신에서 다시 올라왔다.
                isEditing: isInput && !state.isDismissing,
                draft: $draft,
                onTextChange: { store.send(.textChanged($0)) },
                onEditingEnd: { store.send(.editingEnded) },
                onTransformBegin: {
                    isTextViewTransforming = true
                    store.send(.transformBegan)
                },
                onTransformCommit: {
                    isTextViewTransforming = false
                    store.send(.placementCommitted($0))
                }
            )
            .rotationEffect(.degrees(placement.rotationDegrees))
            .position(placement.center(in: canvasSize))

            if !isInput {
                arrangeControls(placement: placement, boxSize: boxSize)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipShape(CanvasPanelShape())
        .position(x: canvasFrame.midX, y: canvasFrame.midY)
    }

    /// 배치 상태 — 캔버스 전체 제스처 면 + 모서리 X.
    @ViewBuilder
    private func arrangeControls(placement: ToppingPlacement, boxSize: CGSize) -> some View {
        let canvasSize = state.canvasSize
        let committedPlacement = state.displayPlacement

        ToppingTransformGestureOverlay(
            draft: $draft,
            // 입력 중 시작한 끌기가 아직 이어지는 동안엔 변형을 끈다 — 두 인식기가 같은 draft 를 번갈아 쓰면 튄다.
            placementCenter: isTextViewTransforming ? nil : committedPlacement.center(in: canvasSize),
            onTap: { point in
                guard committedPlacement.contains(point, renderedSize: boxSize, canvasSize: canvasSize) else { return }
                store.send(.arrangedTextTapped)
            },
            onCommit: { store.send(.placementCommitted($0)) }
        )

        Button { store.send(.deleteTapped) } label: {
            ToppingHandleIcon(.icClose)
        }
        .buttonStyle(.plain)
        .position(
            placement.handleCenter(
                horizontal: -1,
                vertical: -1,
                frameSize: ToppingSelectionFrame.size(around: boxSize),
                cornerOffset: ToppingHandle.cornerOffset,
                in: canvasSize
            )
        )
    }

    // MARK: - 입력 도구

    /// 키보드를 따라 올라가는 층 — 팝오버 + 툴바.
    private var inputChrome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
                .allowsHitTesting(false)

            if state.isColorPopoverPresented {
                TextToppingColorPopover(selectedColor: state.color) { store.send(.colorSelected($0)) }
            }

            TextToppingToolbar(
                color: state.color,
                type: state.type,
                alignment: state.alignment,
                characterCount: state.text.count,
                onColorTap: { store.send(.colorButtonTapped) },
                onTypeTap: { store.send(.typeButtonTapped) },
                onAlignmentTap: { store.send(.alignmentButtonTapped) }
            )
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY
            } action: { minY in
                toolbarMinY = minY
            }
        }
    }
}

/// 화면 + 캔버스 패널 두 겹 — even-odd 로 채우면 캔버스 자리만 뚫리고, 그 구멍으로 뒤의 C-001 캔버스가 보인다.
private struct ScreenExcludingCanvasShape: Shape {
    let canvasFrame: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        // `CanvasPanelShape` 는 원점 (0, 0) 기준으로 그린다 — 제 크기로 그린 뒤 캔버스 자리로 옮긴다.
        let panelPath = CanvasPanelShape()
            .path(in: CGRect(origin: .zero, size: canvasFrame.size))
            .offsetBy(dx: canvasFrame.minX, dy: canvasFrame.minY)
        path.addPath(panelPath)
        return path
    }
}
