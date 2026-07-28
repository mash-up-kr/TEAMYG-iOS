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
    @State private var store: InviteCodeStore
    /// 클립보드 문자열 존재 여부만으로 노출 결정 — 내용 형식 검사는 시스템
    /// 붙여넣기 허용 팝업을 띄우므로 하지 않고, 탭 이후 Store 가 검증한다.
    @State private var isPasteButtonVisible = false

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

                if isPasteButtonVisible {
                    pasteButton
                        .frame(maxWidth: .infinity)
                }
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
        // 진입 시(initial) + 코드 복사를 위해 앱을 나갔다 돌아왔을 때 클립보드 확인
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if newPhase == .active {
                isPasteButtonVisible = UIPasteboard.general.hasStrings
            }
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

    // MARK: - 붙여넣기 (시스템 PasteButton — 탭 시점에만 클립보드 접근이 허용돼 팝업이 없다)

    private var pasteButton: some View {
        PasteButton(payloadType: String.self) { strings in
            guard let pastedString = strings.first else { return }
            Task { @MainActor in
                store.send(.pasted(pastedString))
                isPasteButtonVisible = false
            }
        }
        .buttonBorderShape(.capsule)
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
        store: InviteCodeStore(joinGroupUseCase: PreviewJoinGroupUseCase(joinError: nil))
    )
}

#Preview("실패 - 최대 인원") {
    InviteCodeView(
        store: InviteCodeStore(joinGroupUseCase: PreviewJoinGroupUseCase(joinError: .groupFull))
    )
}

/// 프리뷰 전용 스텁 — 서버 호출 없이 성공/실패를 즉시 확인 (`joinError == nil` 이면 성공).
/// GroupView 프리뷰도 함께 사용하므로 internal.
struct PreviewJoinGroupUseCase: JoinGroupUseCase {
    let joinError: JoinGroupError?

    func join(inviteCode: String) async throws {
        if let joinError {
            throw joinError
        }
    }
}
