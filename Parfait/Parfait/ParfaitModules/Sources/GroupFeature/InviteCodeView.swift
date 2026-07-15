//
//  InviteCodeView.swift
//  GroupFeature
//
//  Created by 김남수 on 7/15/26.
//

import GroupDomain
import SwiftUI
import UIComponent

public struct InviteCodeView: View {
    @State private var store: InviteCodeStore

    public init(store: InviteCodeStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
                .padding(.bottom, 8)
            description
                .padding(.bottom, 69)

            InviteCodeInputField(
                inviteCode: store.binding(\.inviteCode, InviteCodeStore.Intent.inviteCodeChanged),
                isFailed: store.state.phase == .failed,
                onTap: { store.send(.inviteCodeFieldTapped) }
            )
            .padding(.bottom, 12)

            errorMessage

            Spacer()

            YGButton("확인", variant: .large) {
                store.send(.confirmTapped)
            }
            .disabled(!store.state.isConfirmEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 2)
        .alert(
            "그룹 참여 완료", // ponytail: 공용 알림 컴포넌트 확정 시 교체
            isPresented: store.binding(
                \.isSuccessAlertPresented,
                InviteCodeStore.Intent.successAlertVisibilityChanged
            )
        ) {
            // 기본 확인 버튼만 사용
        } message: {
            Text("초대코드로 그룹에 참여했어요")
        }
    }

    // MARK: - 상단 안내

    private var title: some View {
        // ponytail: 디자인 카피 확정 시 교체
        Text("초대코드를 입력해주세요")
            .suit(.title02Bold)
            .foregroundStyle(.gray900)
    }

    private var description: some View {
        // ponytail: 디자인 카피 확정 시 교체
        Text("그룹장에게 받은 초대코드를 입력하면 그룹에 참여할 수 있어요")
            .suit(.body02Regular)
            .foregroundStyle(.gray500)
    }

    // MARK: - 에러 메시지 (기본 hidden, 공간은 항상 예약해 레이아웃 밀림 방지)

    private var errorMessage: some View {
        // ponytail: 에러 메시지 문구 확정 시 교체
        Text("유효하지 않은 초대코드예요")
            .suit(.caption01Regular)
            .foregroundStyle(.cherry600)
            .opacity(store.state.phase == .failed ? 1 : 0)
    }
}

#Preview("성공") {
    InviteCodeView(
        store: InviteCodeStore(joinGroupUseCase: PreviewJoinGroupUseCase(shouldSucceed: true))
    )
}

#Preview("실패") {
    InviteCodeView(
        store: InviteCodeStore(joinGroupUseCase: PreviewJoinGroupUseCase(shouldSucceed: false))
    )
}

/// 프리뷰 전용 스텁 — 서버 호출 없이 성공/실패를 즉시 확인.
private struct PreviewJoinGroupUseCase: JoinGroupUseCase {
    let shouldSucceed: Bool

    func join(inviteCode: String) async throws {
        if !shouldSucceed {
            throw PreviewJoinGroupError.stub
        }
    }
}

private enum PreviewJoinGroupError: Error {
    case stub
}
