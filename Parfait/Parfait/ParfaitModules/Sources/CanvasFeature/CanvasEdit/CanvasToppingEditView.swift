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
    private let toppingRenderer: CanvasToppingRenderer

    init(store: CanvasEditStore, toppingRenderer: CanvasToppingRenderer) {
        _store = State(initialValue: store)
        self.toppingRenderer = toppingRenderer
    }

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            board
                .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)
                .overlay(alignment: .bottom) {
                    borderPanel
                }
                .ygToastOverlay($toasts)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, .padding7)
                .padding(.top, .padding4)
        }
        .disabled(store.state.saveState == .saving)
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(.title("배치"), onClose: { store.send(.closeTapped) })
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            YGButton("캔버스에 쌓기", variant: .large) { store.send(.confirmTapped) }
                .padding(.horizontal, .padding7)
                .padding(.vertical, .padding6)
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
        .task {
            for await event in store.eventStream() {
                switch event {
                case .otherToppingSelected:
                    toasts = [YGToastItem(kind: .warning, message: "다른 사람의 사진은 편집할 수 없어요")]
                case .saveFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "편집 내용을 저장하지 못했어요, 잠시 후 다시 시도해 주세요")
                    )
                }
            }
        }
    }

    private var board: some View {
        CanvasToppingEditBoard(
            background: store.state.background,
            toppings: store.state.activeToppings,
            selectedToppingID: store.state.selectedToppingID,
            onToppingTap: { store.send(.toppingTapped($0)) },
            onPlacementChange: {
                store.send(.toppingPlacementChanged(toppingID: $0, placement: $1))
            },
            onDeleteTap: { store.send(.toppingDeleteTapped($0)) },
            onTouchBegan: store.state.borderPanelTopping == nil ? nil : { store.send(.borderPanelClosed) }
        )
    }

    @ViewBuilder
    private var borderPanel: some View {
        if let topping = store.state.borderPanelTopping {
            ToppingBorderPanel(
                border: topping.border,
                onWidthChange: { store.send(.borderWidthChanged($0)) },
                onColorSelect: { store.send(.borderColorSelected($0)) },
                onCollapseTap: { store.send(.borderPanelClosed) }
            )
        } else {
            ToppingBorderPanelHandle(onExpandTap: { store.send(.borderPanelExpandTapped) })
        }
    }
}
