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
        .padding(.horizontal, .padding7)
        .ygTopBar(.detail(title: "계정 정보"))
        .background(.whiteFixed)
    }
}

#Preview {
    AccountInfoView(
        store: AccountInfoStore(state: .init(nickname: "대충지은랜덤닉네임"))
    )
}
