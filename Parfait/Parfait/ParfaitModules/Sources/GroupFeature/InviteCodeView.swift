//
//  InviteCodeView.swift
//  GroupFeature
//
//  Created by 김남수 on 7/15/26.
//

import GroupDomain
import SwiftUI
import UIComponent
import UIKit

public struct InviteCodeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var store: InviteCodeStore

    public init(store: InviteCodeStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            VStack(alignment: .leading, spacing: 0) {
                title
                    .padding(.bottom, 8)
                description
                    .padding(.bottom, 69)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 입력창은 화면 중앙, 에러 메시지 리딩은 입력창 리딩과 일치하도록
            // 입력창 너비로 폭을 고정한 leading 정렬 그룹으로 묶는다.
            VStack(alignment: .leading, spacing: 12) {
                InviteCodeInputField(
                    inviteCode: store.binding(
                        \.inviteCode,
                        InviteCodeStore.Intent.inviteCodeChanged
                    ),
                    isFailed: store.state.isFailed,
                    onTapWhileFailed: { store.send(.inviteCodeFieldTapped) }
                )

                errorMessage
            }
            .frame(width: InviteCodeInputField.fieldWidth, alignment: .leading)

            Spacer()

            YGButton("확인", variant: .large) {
                store.send(.confirmTapped)
            }
            .disabled(!store.state.isConfirmEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 20)
        // 진입 시(initial) + 코드 복사를 위해 앱을 나갔다 돌아왔을 때 클립보드를 읽어
        // 입력창에 자동으로 채운다. 다른 앱에서 복사한 내용이면 시스템 붙여넣기
        // 허용 알럿이 뜨고, 거부 시 nil 이라 아무 일도 없다. 검증은 Store 가 한다.
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            guard newPhase == .active,
                  store.state.inviteCode.isEmpty, // 입력 중인 내용을 덮어쓰지 않는다
                  UIPasteboard.general.hasStrings,
                  let pastedString = UIPasteboard.general.string
            else { return }
            store.send(.pasted(pastedString))
        }
        .onDisappear {
            store.send(.screenDisappeared)
        }
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
        // 성공 알럿의 확인을 눌러 알럿이 닫히면 참여 플로우가 끝난다.
        // ponytail: 캔버스(C-001) 가 붙으면 목록 대신 참여한 그룹으로 이어져야 한다.
        //           그때까지는 목록으로 되돌려 그룹이 늘어난 걸 보여준다 (그룹 만들기와 같은 처리).
        .onChange(of: store.state.isSuccessAlertPresented) { wasPresented, isPresented in
            if wasPresented, !isPresented {
                dismiss()
            }
        }
        .ygTopBar(.detail(title: "그룹 참여하기"))
    }

    // MARK: - 상단 안내

    private var title: some View {
        Text("초대코드를 입력해 주세요")
            .suit(.title02Bold)
            .foregroundStyle(.gray900)
    }

    private var description: some View {
        Text("초대코드는 그룹원에게 직접 받을 수 있어요")
            .suit(.body02Regular)
            .foregroundStyle(.gray500)
    }

    // MARK: - 에러 메시지 (기본 hidden, 공간은 항상 예약해 레이아웃 밀림 방지)

    private var errorMessage: some View {
        Text(errorMessageText)
            .suit(.caption01Regular)
            .foregroundStyle(.cherry600)
            .opacity(store.state.isFailed ? 1 : 0)
    }

    /// 실패 사유별 안내 문구. `nil`(비실패 상태)은 숨겨진 채 공간만 차지하므로 아무 문구나 무방.
    private var errorMessageText: String {
        switch store.state.joinError {
        case .invalidInviteCode, nil: "유효하지 않은 초대코드예요"
        case .groupFull: "이미 최대 인원이 모두 참여한 그룹이에요"
        case .alreadyJoined: "이미 참여한 그룹이에요"
        case .server(let message): message
        case .unknown: "잠시 후 다시 시도해 주세요"
        }
    }
}

#Preview("성공") {
    InviteCodeView(
        store: InviteCodeStore(groupUseCase: PreviewGroupUseCase())
    )
}

#Preview("실패 - 최대 인원") {
    InviteCodeView(
        store: InviteCodeStore(groupUseCase: PreviewGroupUseCase(joinError: .groupFull))
    )
}
