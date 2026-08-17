//
//  CreateGroupStore.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import Common
import GroupDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class CreateGroupStore: MVIStore {
    public private(set) var state = State()

    private let groupUseCase: any GroupUseCase
    @ObservationIgnored private var createTask: Task<Void, Never>?

    public init(groupUseCase: any GroupUseCase) {
        self.groupUseCase = groupUseCase
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .nameChanged(let name):
            state.name = GroupNamePolicy.truncated(name)
        case .nicknameChanged(let nickname):
            state.nickname = String(nickname.prefix(NicknameValidator.maxLength))
        case .memberCountTapped(let memberCount):
            toggleMemberCount(memberCount)
        case .confirmTapped:
            presentCreateConfirmPopup()
        case .createConfirmPopupVisibilityChanged(let isPresented):
            state.isCreateConfirmPopupPresented = isPresented
        case .createConfirmed:
            state.isCreateConfirmPopupPresented = false
            beginCreateRequest()
        case .createSucceeded(let group):
            state.phase = .created(group)
        case .createFailed(let createError):
            state.phase = .failed(createError)
        case .failureAcknowledged:
            clearFailure()
        case .screenDisappeared:
            cancelCreateRequest()
        }
    }

    /// 같은 칸을 다시 누르면 해제 — 잘못 고른 뒤 선택을 비울 방법이 이것뿐이다.
    private func toggleMemberCount(_ memberCount: Int) {
        state.memberCount = state.memberCount == memberCount ? nil : memberCount
    }

    private func presentCreateConfirmPopup() {
        guard state.isConfirmEnabled else { return }
        state.isCreateConfirmPopupPresented = true
    }

    private func clearFailure() {
        guard case .failed = state.phase else { return }
        state.phase = .idle
    }

    private func cancelCreateRequest() {
        createTask?.cancel()
        createTask = nil
        if state.phase == .loading {
            state.phase = .idle
        }
    }

    /// 입력이 모두 유효할 때만 생성 요청을 시작한다. 진행 중이면 중복 실행하지 않는다.
    private func beginCreateRequest() {
        guard createTask == nil, let draft = state.draft else { return }
        state.phase = .loading
        createTask = Task {
            await requestCreate(draft)
            createTask = nil
        }
    }

    /// 서버 요청 후 결과를 다시 `send` 로 되돌려 상태 변이가 `send` 내부에서만 일어나도록 한다.
    /// 제출 시점의 입력을 파라미터로 받아, 통신 중 사용자가 값을 바꿔도 실제로 보낸 것과 어긋나지 않게 한다.
    private func requestCreate(_ draft: GroupDraft) async {
        do {
            let group = try await groupUseCase.create(draft)
            send(.createSucceeded(group))
        } catch is CancellationError {
            // 화면 이탈로 취소됨 — 실패로 오인하지 않고 조용히 종료.
        } catch {
            send(.createFailed(error as? CreateGroupError ?? .unknown))
        }
    }

    public struct State: Equatable {
        public var name = ""
        public var nickname = ""
        public var memberCount: Int?
        public var phase = Phase.idle
        public var isCreateConfirmPopupPresented = false

        /// 세 입력이 모두 유효할 때만 만들어지는 제출용 값. `nil` 이면 아직 보낼 수 없다는 뜻.
        ///
        /// 그룹명과 닉네임의 검증기가 다르다 — 닉네임은 `Common` 의 `NicknameValidator` 를 그대로
        /// 쓰고(앱 닉네임 화면과 같은 정책), 그룹명만 `GroupDomain` 의 규칙을 따른다.
        public var draft: GroupDraft? {
            guard nameViolation == nil, nicknameErrorMessage == nil, let memberCount else { return nil }
            return GroupDraft(name: name, nickname: nickname, memberCount: memberCount)
        }

        /// 그룹명 위반 사유. 아직 한 글자도 안 쳤으면 에러로 다그치지 않는다(Empty 상태).
        public var nameViolation: GroupNameViolation? {
            name.isEmpty ? .empty : GroupNamePolicy.validate(name)
        }

        /// 닉네임 위반 안내 문구. `NicknameValidator` 가 사유 대신 문구를 돌려주므로 그대로 받는다.
        public var nicknameErrorMessage: String? {
            NicknameValidator.errorMessage(for: nickname)
        }

        /// 화면에 빨간 문구로 띄울 위반 — 빈 입력은 "아직 안 씀"이지 "틀림"이 아니라 뺀다.
        public var displayedNameViolation: GroupNameViolation? {
            name.isEmpty ? nil : nameViolation
        }

        public var displayedNicknameErrorMessage: String? {
            nickname.isEmpty ? nil : nicknameErrorMessage
        }

        public var isConfirmEnabled: Bool {
            phase != .loading && draft != nil
        }

        /// 생성이 끝나 화면을 떠나야 하는 시점의 결과. `nil` 이면 아직 머무른다.
        public var createdGroup: ParfaitGroup? {
            if case .created(let group) = phase { return group }
            return nil
        }

        public var createError: CreateGroupError? {
            if case .failed(let createError) = phase { return createError }
            return nil
        }
    }

    public enum Phase: Equatable {
        case idle
        case loading
        case created(ParfaitGroup)
        case failed(CreateGroupError)
    }

    public enum Intent {
        case nameChanged(String)
        case nicknameChanged(String)
        case memberCountTapped(Int)
        case confirmTapped
        /// 팝업 자체의 표시 여부 — 취소·바깥 탭으로 닫히는 경로가 여기로 온다.
        case createConfirmPopupVisibilityChanged(Bool)
        case createConfirmed
        /// `requestCreate(_:)` 완료 결과 — View 가 아니라 Store 내부에서만 보낸다.
        case createSucceeded(ParfaitGroup)
        case createFailed(CreateGroupError)
        case failureAcknowledged
        case screenDisappeared
    }
}
