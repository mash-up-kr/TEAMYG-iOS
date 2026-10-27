//
//  CanvasToppingEditView.swift
//  CanvasFeature
//
//  Created by 박서연 on 10/9/26.
//

import SwiftUI
import UIComponent

struct CanvasToppingEditView: View {
    @State private var store: CanvasEditStore
    @State private var toasts: [YGToastItem] = []
    /// 상단 바·버튼을 뺀 영역의 화면 좌표.
    @State private var contentFrame: CGRect = .zero
    @Environment(\.canvasBoardEntrance) private var entrance
    private let toppingRenderer: CanvasToppingRenderer

    init(store: CanvasEditStore, toppingRenderer: CanvasToppingRenderer) {
        _store = State(initialValue: store)
        self.toppingRenderer = toppingRenderer
    }

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()
                .canvasEditChrome()

            if let pinnedBoardFrame {
                boardStack
                    .frame(width: pinnedBoardFrame.width, height: pinnedBoardFrame.height)
                    .position(
                        x: pinnedBoardFrame.midX - contentFrame.minX,
                        y: pinnedBoardFrame.midY - contentFrame.minY
                    )
            } else {
                boardStack
                    .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, .padding7)
                    // C-001 캔버스와 위쪽 끝을 맞춘다 — 전환 중 캔버스가 위로 올라가지 않고 아래·옆으로만 줄어든다.
                    .padding(.top, .padding6)
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            contentFrame = frame
        }
        .disabled(store.state.saveState == .saving)
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(.title("배치"), onClose: { store.send(.closeTapped) })
                .canvasEditChrome()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            YGButton("캔버스에 쌓기", variant: .large) { store.send(.confirmTapped) }
                .padding(.horizontal, .padding7)
                .padding(.top, .padding6)
                .padding(.bottom, .padding1)
                .canvasEditChrome()
        }
        .environment(\.canvasToppingRenderer, toppingRenderer)
        .canvasEditLifecycle(
            isSaving: store.state.saveState == .saving,
            send: { store.send($0) }
        )
        .ygPopup(
            isPresented: store.binding(\.showsExitPopup, CanvasEditStore.Intent.exitPopupVisibilityChanged),
            title: "사진 편집을 그만둘까요?",
            description: "지금까지 진행한 내용은 저장되지 않아요.\n정말 그만두시겠어요?",
            secondaryTitle: "그만두기",
            primaryTitle: "계속 편집",
            secondaryAction: { store.send(.discardTapped) }
        )
        .onAppear { store.send(.toppingEditScreenAppeared) }
        .task {
            for await event in store.eventStream() {
                switch event {
                case .otherToppingSelected:
                    toasts = [YGToastItem(kind: .warning, message: "다른 사람의 사진은 편집할 수 없어요")]
                case .otherTextSelected:
                    toasts = [YGToastItem(kind: .warning, message: "다른 사람의 텍스트는 편집할 수 없어요")]
                case .saveFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "편집 내용을 저장하지 못했어요, 잠시 후 다시 시도해 주세요")
                    )
                }
            }
        }
    }

    /// C-001 캔버스와 같은 자리·크기 — 전환 중 캔버스가 움직이지 않고 주변만 페이드된다(C-106 처럼).
    /// 그 자리에 두면 상단 바·버튼과 겹치는 기기(세로가 짧은 화면)에선 `nil` 이라 이 화면 크기에 맞춘다.
    private var pinnedBoardFrame: CGRect? {
        guard let frame = entrance?.sourceFrame,
              frame.width > 0,
              contentFrame.height > 0,
              frame.minY >= contentFrame.minY,
              // 버튼 위 여백(`padding6`)은 비어 있어 캔버스가 걸쳐도 된다 — 버튼 자체와만 안 겹치면 된다.
              frame.maxY <= contentFrame.maxY + .padding6
        else { return nil }
        return frame
    }

    private var boardStack: some View {
        board
            .overlay(alignment: .bottom) {
                borderPanel
                    .canvasEditChrome()
            }
            .canvasBoardFrame()
            .canvasBoardEntrance()
            .ygToastOverlay($toasts)
    }

    private var board: some View {
        CanvasToppingEditBoard(
            background: store.state.background,
            toppings: store.state.activeToppings,
            texts: store.state.activeTexts,
            selectedToppingID: store.state.selectedToppingID,
            selectedTextID: store.state.selectedTextID,
            onToppingTap: { store.send(.toppingTapped($0)) },
            onPlacementChange: {
                store.send(.toppingPlacementChanged(toppingID: $0, placement: $1))
            },
            onDeleteTap: { store.send(.toppingDeleteTapped($0)) },
            onTextTap: { store.send(.textTapped($0)) },
            onTextPlacementChange: {
                store.send(.textPlacementChanged(textID: $0, placement: $1))
            },
            onTextDeleteTap: { store.send(.textDeleteTapped($0)) },
            onEmptyTap: { store.send(.emptyAreaTapped) },
            onBorderPanelDismiss: store.state.borderPanelTopping == nil ? nil : { store.send(.borderPanelClosed) }
        )
    }

    /// 테두리는 사진만 바꿀 수 있다 — 사진을 골랐을 때만 핸들을 띄운다.
    @ViewBuilder
    private var borderPanel: some View {
        if let topping = store.state.borderPanelTopping {
            ToppingBorderPanel(
                border: topping.border,
                onWidthChange: { store.send(.borderWidthChanged($0)) },
                onColorSelect: { store.send(.borderColorSelected($0)) },
                onCollapseTap: { store.send(.borderPanelClosed) }
            )
        } else if store.state.selectedTopping != nil {
            ToppingBorderPanelHandle(onExpandTap: { store.send(.borderPanelExpandTapped) })
        }
    }
}
