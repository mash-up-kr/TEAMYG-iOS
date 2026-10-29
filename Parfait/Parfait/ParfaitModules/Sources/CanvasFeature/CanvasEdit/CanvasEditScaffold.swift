//
//  CanvasEditScaffold.swift
//  CanvasFeature
//
//  Created by 박서연 on 10/9/26.
//

import SwiftUI
import UIComponent

/// "그만둘까요?" 팝업의 공통 설명 — 토핑 추가·배경 변경·토핑 편집이 같이 쓴다.
let canvasQuitPopupDescription = "지금까지 진행한 내용은 저장되지 않아요.\n정말 그만두시겠어요?"

extension View {
    /// 배경 변경·토핑 편집 화면 공통 틀 — 저장 중 입력 막기, 상단 닫기 바, 하단 확정 버튼, 나가기 팝업, 수명주기.
    func canvasEditScaffold(
        store: CanvasEditStore,
        title: String,
        confirmTitle: String,
        exitPopupTitle: String
    ) -> some View {
        modifier(
            CanvasEditScaffoldModifier(
                store: store,
                title: title,
                confirmTitle: confirmTitle,
                exitPopupTitle: exitPopupTitle
            )
        )
    }
}

private struct CanvasEditScaffoldModifier: ViewModifier {
    let store: CanvasEditStore
    let title: String
    let confirmTitle: String
    let exitPopupTitle: String
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        let isSaving = store.state.saveState == .saving
        content
            .disabled(isSaving)
            .safeAreaInset(edge: .top, spacing: 0) {
                YGFloatingBar(.title(title), onClose: { store.send(.closeTapped) })
                    .canvasEditChrome()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                YGButton(confirmTitle, variant: .large) { store.send(.confirmTapped) }
                    .padding(.horizontal, .padding7)
                    .padding(.top, .padding6)
                    .padding(.bottom, .padding1)
                    .canvasEditChrome()
            }
            .toolbar(.hidden, for: .navigationBar)
            .ygLoading(isSaving)
            .onAppear {
                store.send(.screenAppeared)
            }
            .onDisappear {
                store.send(.screenDisappeared)
            }
            .onChange(of: scenePhase) { _, newScenePhase in
                switch newScenePhase {
                case .active:
                    store.send(.sceneBecameActive)
                case .background:
                    store.send(.sceneEnteredBackground)
                default:
                    break
                }
            }
            .ygPopup(
                isPresented: store.binding(\.showsExitPopup, CanvasEditStore.Intent.exitPopupVisibilityChanged),
                title: exitPopupTitle,
                description: canvasQuitPopupDescription,
                secondaryTitle: "그만두기",
                primaryTitle: "계속 편집",
                secondaryAction: { store.send(.discardTapped) }
            )
    }
}
