//
//  GroupSideMenuView.swift
//  GroupFeature
//
//  Created by 신상우 on 8/10/26.
//

import Combine
import Common
import GroupDomain
import SwiftUI
import UIComponent
import UIKit

/// 그룹 사이드메뉴 (S-101). 그룹 속 내 닉네임 수정 · 그룹원 목록 · 초대 코드 복사 · 나가기/신고를 담는다.
///
/// 닉네임 변경(S-102)은 키보드 엔터 또는 키보드 위 확인 버튼으로 제출한다 — 확인 버튼은
/// 키보드가 올라와 있을 때만 노출되고, 유효성 검사를 통과하지 못하면 비활성화된다.
public struct GroupSideMenuView: View {
    @State private var store: GroupSideMenuStore
    private let onExit: (GroupSideMenuStore.ExitOutcome) -> Void

    /// 타이핑이 직접 닿는 입력 사본. 로컬로 받는 이유는 `CreateGroupView.nameInput` 주석 참고
    /// (최대 길이에서 Store 값이 안 변해 화면과 어긋나는 문제 + docs/mvi.md 고빈도 입력 지침).
    @State private var nicknameInput: String
    /// 키보드 위 확인 버튼의 노출 조건. 포커스는 `YGTextField` 내부에 있어 밖에서 못 읽으므로
    /// 키보드 노티피케이션으로 판단한다.
    @State private var isKeyboardVisible = false

    /// 상단 바 아래 첫 입력까지의 간격 (A-005 와 동일).
    private static let topInset: CGFloat = 16
    /// 입력 묶음(닉네임 / 그룹원 / 초대 코드 / 나가기·신고) 사이 간격.
    private static let sectionGap: CGFloat = .gap8
    private static let horizontalInset: CGFloat = 20

    /// - Parameter onExit: 나가기/신고 완료 시 결과를 넘긴다. G-001 복귀와 확인 토스트는 호출부가 결정한다.
    public init(
        store: GroupSideMenuStore,
        onExit: @escaping (GroupSideMenuStore.ExitOutcome) -> Void = { _ in }
    ) {
        _store = State(initialValue: store)
        _nicknameInput = State(initialValue: store.state.nickname)
        self.onExit = onExit
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.gray50)
            // 입력 영역 밖 아무 데나 누르면 키보드를 내린다.
            .contentShape(.rect)
            .onTapGesture { dismissKeyboard() }
            .safeAreaInset(edge: .bottom) {
                if isKeyboardVisible {
                    nicknameConfirmButton
                }
            }
            .ygTopBar(.detail(title: store.state.groupName))
            .ygPopup(
                isPresented: store.binding(\.isLeavePopupPresented) { .exitPopupVisibilityChanged(.leave, $0) },
                title: "그룹에서 나갈까요?",
                description: "그룹에서 나가도\n그룹에 올렸던 사진은 지워지지 않아요",
                secondaryTitle: "나가기",
                primaryTitle: "그만두기",
                secondaryAction: { store.send(.exitConfirmed(.leave)) }
            )
            .ygPopup(
                isPresented: store.binding(\.isReportPopupPresented) { .exitPopupVisibilityChanged(.report, $0) },
                title: "그룹을 신고할까요?",
                description: "신고 후에는 그룹에서 자동으로 나가지며,\n그룹은 운영 정책에 따라 처리 돼요.",
                secondaryTitle: "신고하기",
                primaryTitle: "그만두기",
                secondaryAction: { store.send(.exitConfirmed(.report)) }
            )
            // 서버가 준 내 닉네임(비동기 도착)을 입력 사본에 맞춘다. 타이핑 반향은 값이 같아 걸러진다.
            .onChange(of: store.state.nickname) { _, nickname in
                if nicknameInput != nickname {
                    nicknameInput = nickname
                }
            }
            .onChange(of: store.state.exitOutcome) { _, exitOutcome in
                guard let exitOutcome else { return }
                onExit(exitOutcome)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) { _ in
                isKeyboardVisible = true
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in
                isKeyboardVisible = false
            }
            .task { store.send(.screenAppeared) }
            .onDisappear { store.send(.screenDisappeared) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state.phase {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let detail):
            loadedContent(detail)
        case .failed:
            loadFailure
        }
    }

    /// 그룹원 수에 따라 페이지 전체가 늘어나므로 화면 통째로 스크롤한다.
    /// 내용이 화면보다 짧으면 스크롤(바운스)도 걸리지 않는다.
    private func loadedContent(_ detail: GroupDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.sectionGap) {
                nicknameField
                memberList(detail)
                YGInviteCard(code: detail.inviteCode, status: inviteCardStatus(detail))
                dangerZone
            }
            .padding(.horizontal, Self.horizontalInset)
            .padding(.top, Self.topInset)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - 닉네임 (S-102)

    private var nicknameField: some View {
        YGTitledTextField(
            title: "그룹 속 내 닉네임",
            text: $nicknameInput,
            placeholder: "닉네임을 입력해 주세요",
            maxLength: NicknameValidator.maxLength,
            errorMessage: store.state.displayedNicknameErrorMessage
        )
        .onChange(of: nicknameInput) { _, _ in
            store.send(.nicknameChanged(nicknameInput))
        }
        .onSubmit { store.send(.nicknameSubmitted) }
    }

    /// 키보드가 올라와 있을 때만 키보드 바로 위에 노출되는 제출 버튼.
    private var nicknameConfirmButton: some View {
        YGButton("확인", variant: .large) {
            store.send(.nicknameSubmitted)
            dismissKeyboard()
        }
        .disabled(!store.state.isNicknameConfirmEnabled)
        .padding(.horizontal, Self.horizontalInset)
        .padding(.bottom, .padding3)
    }

    // MARK: - 그룹원

    /// 전원을 다 그린다. 넘치는 인원은 페이지 스크롤이 감당한다.
    private func memberList(_ detail: GroupDetail) -> some View {
        VStack(alignment: .leading, spacing: .gap4) {
            Text("그룹원 (\(detail.members.count))")
                .suit(.body02Regular)
                .foregroundStyle(.gray400)

            VStack(alignment: .leading, spacing: .gap4) {
                ForEach(detail.members) { member in
                    YGUserChip(
                        nickname: member.isMe ? "\(member.nickname) (나)" : member.nickname,
                        type: member.nametagType.chipType,
                        isSelf: member.isMe
                    )
                }
            }
            .padding(.top, .padding3)
        }
    }

    // MARK: - 초대 코드

    /// 남은 자리가 없으면 "최대 인원 도달" 상태로 — 복사 버튼도 함께 비활성화된다.
    private func inviteCardStatus(_ detail: GroupDetail) -> YGInviteCard.Status {
        detail.remainingSeatCount > 0 ? .active(remainingCount: detail.remainingSeatCount) : .invalid
    }

    // MARK: - 나가기 · 신고 (S-103)

    private var dangerZone: some View {
        YGDangerZone {
            YGActionItem("그룹 나가기") { store.send(.exitPopupVisibilityChanged(.leave, true)) }
            YGActionItem("그룹 신고하기") { store.send(.exitPopupVisibilityChanged(.report, true)) }
        }
    }

    // MARK: - 조회 실패

    /// 상세 조회 실패 안내. 전용 시안이 없어 G-001 실패 문구 톤을 따른다.
    private var loadFailure: some View {
        Text("앗, 그룹 정보를 불러오지 못했어요.")
            .suit(.title03SemiBold)
            .foregroundStyle(.gray500)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Preview

@MainActor
private func previewSideMenuStore(
    detail: GroupDetail? = .previewSample,
    configure: (GroupSideMenuStore) -> Void = { _ in }
) -> GroupSideMenuStore {
    let stub = PreviewGroupSideMenuStub(detail: detail)
    let store = GroupSideMenuStore(
        groupID: "preview-group",
        groupName: "그룹이름",
        fetchGroupDetailUseCase: stub,
        changeGroupNicknameUseCase: stub,
        leaveGroupUseCase: stub,
        reportGroupUseCase: stub
    )
    configure(store)
    return store
}

#Preview("기본 (S-101)") {
    NavigationStack {
        GroupSideMenuView(store: previewSideMenuStore())
    }
}

#Preview("나가기 팝업 (S-103)") {
    NavigationStack {
        GroupSideMenuView(store: previewSideMenuStore { store in
            store.send(.detailLoadFinished(.previewSample))
            store.send(.exitPopupVisibilityChanged(.leave, true))
        })
    }
}

#Preview("신고 팝업 (S-103)") {
    NavigationStack {
        GroupSideMenuView(store: previewSideMenuStore { store in
            store.send(.detailLoadFinished(.previewSample))
            store.send(.exitPopupVisibilityChanged(.report, true))
        })
    }
}

#Preview("조회 실패") {
    NavigationStack {
        GroupSideMenuView(store: previewSideMenuStore(detail: nil))
    }
}

/// 프리뷰 전용 스텁. `detail` 이 nil 이면 조회 실패를 흉내낸다.
private struct PreviewGroupSideMenuStub: FetchGroupDetailUseCase, ChangeGroupNicknameUseCase,
                                         LeaveGroupUseCase, ReportGroupUseCase {
    let detail: GroupDetail?

    func fetchDetail(groupID: String) async throws -> GroupDetail {
        guard let detail else { throw CocoaError(.coderValueNotFound) }
        return detail
    }

    func changeNickname(groupID: String, nickname: String) async throws {}
    func leave(groupID: String) async throws {}
    func report(groupID: String) async throws {}
}

private extension GroupDetail {
    static var previewSample: GroupDetail {
        let others = (1...10).map { index in
            GroupMember(
                id: "preview-member-\(index)",
                nickname: "아니야나그런데기니야기니라니까",
                nametagType: NametagType.allCases[index % NametagType.allCases.count],
                isMe: false
            )
        }
        return GroupDetail(
            id: "preview-group",
            name: "그룹이름",
            inviteCode: "WDIDCJ",
            memberLimit: 12,
            members: [
                GroupMember(id: "preview-member-me", nickname: "잠탈전용닉네임2", nametagType: .type4, isMe: true)
            ] + others
        )
    }
}
