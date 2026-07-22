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
        VStack(spacing: .gap8) {
            YGTitledTextField(
                title: "닉네임",
                text: store.binding(\.nickname, AccountInfoStore.Intent.nicknameChanged),
                placeholder: "닉네임을 입력해주세요",
                maxLength: NicknameValidator.maxLength,
                errorMessage: store.state.nicknameErrorMessage
            )
            dangerZone
        }
        .padding(.horizontal, .padding7)
        .ygTopBar(.detail(title: "계정 정보"))
        .background(.whiteFixed)
    }

    // MARK: - 위험 액션 (로그아웃·서비스 탈퇴)

    private var dangerZone: some View {
        VStack(spacing: 0) {
            YGActionItem("로그아웃") { store.send(.logoutTapped) }
            DashedHorizontalLine()
                .stroke(Color.gray100, style: dashedStrokeStyle)
                .frame(height: 1)
            YGActionItem("서비스 탈퇴하기") { store.send(.withdrawTapped) }
        }
        .padding(.vertical, .padding2)
        .overlay {
            Rectangle()
                .strokeBorder(Color.gray100, style: dashedStrokeStyle)
        }
    }

    private var dashedStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 1, dash: [4, 4])
    }
}

/// 점선 가로줄. `Divider` 는 dash 를 지원하지 않아 직접 그린다.
private struct DashedHorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

#Preview {
    AccountInfoView(
        store: AccountInfoStore(state: .init(nickname: "대충지은랜덤닉네임"))
    )
}
