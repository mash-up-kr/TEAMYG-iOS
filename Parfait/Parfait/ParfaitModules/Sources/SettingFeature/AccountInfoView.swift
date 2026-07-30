//
//  AccountInfoView.swift
//  SettingFeature
//
//  Created by 김남수 on 7/22/26.
//

import Common
import SwiftUI
import UIComponent

public struct AccountInfoView: View {
    @State private var store: AccountInfoStore
    @FocusState private var isNicknameFocused: Bool
    @Environment(\.dismiss) private var dismiss

    public init(store: AccountInfoStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        YGTitledTextField(
            title: "닉네임",
            text: store.binding(\.nickname, AccountInfoStore.Intent.nicknameChanged),
            placeholder: "닉네임을 입력해주세요",
            maxLength: NicknameValidator.maxLength,
            errorMessage: store.state.nicknameErrorMessage
        )
        .focused($isNicknameFocused)
        .submitLabel(.done)
        .onSubmit { store.send(.confirmTapped) }
        .padding(.horizontal, .padding7)
        .ygTopBar(.detail(title: "계정 정보"))
        .background(.whiteFixed)
        .safeAreaInset(edge: .bottom) {
            // 닉네임 편집 중에만 키보드 위로 노출
            if isNicknameFocused {
                YGButton("확인", variant: .large) { store.send(.confirmTapped) }
                    .disabled(store.state.nicknameErrorMessage != nil)
                    .padding(.horizontal, .padding7)
                    .padding(.vertical, .padding7)
            }
        }
        .task {
            for await event in store.events {
                switch event {
                case .nicknameSaved:
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    AccountInfoView(
        store: AccountInfoStore(state: .init(nickname: "대충지은랜덤닉네임"))
    )
}
