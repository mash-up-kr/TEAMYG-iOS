//
//  JoinGroupNicknameView.swift
//  GroupFeature
//
//  Created by 박서연 on 10/6/26.
//

import Common
import GroupDomain
import SwiftUI
import UIComponent

struct JoinGroupNicknameView: View {
    @State private var store: JoinGroupNicknameStore
    @State private var nicknameInput: String
    private let onCompleted: () -> Void

    init(store: JoinGroupNicknameStore, onCompleted: @escaping () -> Void) {
        _store = State(initialValue: store)
        _nicknameInput = State(initialValue: store.state.nickname)
        self.onCompleted = onCompleted
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(store.state.groupName)에서 사용할\n닉네임을 입력해 주세요")
                    .suit(.title02Bold)
                    .foregroundStyle(.gray900)
                    .padding(.bottom, 8)
                Text("\(store.state.groupName)에서만 공유되는 닉네임이에요")
                    .suit(.body02Regular)
                    .foregroundStyle(.gray500)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            nicknameField

            Spacer()

            YGButton("확인", variant: .large) {
                store.send(.confirmTapped)
            }
            .disabled(!store.state.isConfirmEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .onChange(of: store.state.isCompleted) { _, isCompleted in
            guard isCompleted else { return }
            onCompleted()
        }
        .task { store.send(.screenAppeared) }
        .onDisappear { store.send(.screenDisappeared) }
    }

    private var nicknameField: some View {
        YGTextField(
            text: $nicknameInput,
            placeholder: "닉네임을 입력해 주세요",
            maxLength: NicknameValidator.maxLength,
            errorMessage: store.state.displayedNicknameErrorMessage
        )
        .onChange(of: nicknameInput) { _, _ in
            store.send(.nicknameChanged(nicknameInput))
        }
        .onChange(of: store.state.nickname) { _, nickname in
            guard nicknameInput.prefix(NicknameValidator.maxLength) != nickname else { return }
            nicknameInput = nickname
        }
    }
}

#Preview {
    JoinGroupNicknameView(
        store: JoinGroupNicknameStore(
            group: JoinedGroup(id: "preview-group", name: "그룹이름"),
            groupUseCase: PreviewGroupUseCase()
        ),
        onCompleted: {}
    )
}
