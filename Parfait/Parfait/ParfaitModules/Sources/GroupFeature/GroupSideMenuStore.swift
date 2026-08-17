//
//  GroupSideMenuStore.swift
//  GroupFeature
//
//  Created by 신상우 on 8/10/26.
//

import Common
import GroupDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class GroupSideMenuStore: MVIStore {
    public private(set) var state: State

    private let groupUseCase: any GroupUseCase
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var nicknameTask: Task<Void, Never>?
    /// 나가기·신고 공용 — 둘 다 성공하면 화면을 떠나므로 동시에 하나만 돈다.
    @ObservationIgnored private var exitTask: Task<Void, Never>?

    public init(groupID: String, groupName: String, groupUseCase: any GroupUseCase) {
        state = State(groupID: groupID, groupName: groupName)
        self.groupUseCase = groupUseCase
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            beginLoad()
        case .detailLoadFinished(let detail):
            applyLoadResult(detail)
        case .nicknameChanged(let nickname):
            applyNicknameInput(nickname)
        case .nicknameSubmitted:
            beginNicknameChange()
        case .nicknameChangeFinished(let savedNickname):
            applyNicknameChangeResult(savedNickname)
        case .exitPopupVisibilityChanged(let exitAction, let isPresented):
            setExitPopupVisibility(exitAction, isPresented: isPresented)
        case .exitConfirmed(let exitAction):
            setExitPopupVisibility(exitAction, isPresented: false)
            beginExit(exitAction)
        case .exitFinished(let exitAction):
            // 실패(nil)는 화면에 머무른다 — 안내 디자인 미정(API 도 미정)이라 다시 시도만 열어 둔다.
            state.completedExit = exitAction
        case .screenDisappeared:
            cancelAllTasks()
        }
    }

    /// 최초 진입 로딩. 진행 중이거나 이미 받았다면 중복 실행하지 않는다.
    private func beginLoad() {
        guard loadTask == nil, state.phase == .idle else { return }
        state.phase = .loading
        let groupID = state.groupID
        loadTask = Task {
            await loadDetail(groupID: groupID)
            loadTask = nil
        }
    }

    private func loadDetail(groupID: String) async {
        do {
            let detail = try await groupUseCase.fetchDetail(groupID: groupID)
            send(.detailLoadFinished(detail))
        } catch is CancellationError {
            // 화면 이탈로 취소됨 — 실패로 오인하지 않는다.
        } catch {
            send(.detailLoadFinished(nil))
        }
    }

    private func applyLoadResult(_ detail: GroupDetail?) {
        guard let detail else {
            state.phase = .failed
            return
        }
        state.phase = .loaded(detail)
        state.groupName = detail.name
        state.nickname = detail.myNickname ?? ""
    }

    private func applyNicknameInput(_ nickname: String) {
        // 최대 길이 자르기는 `YGTextField` 가 바인딩에 되써서 맡는다 — 여기서 자르면 잘린 값이
        // 직전과 같아 바인딩이 안 바뀌고, 화면의 자르기도 발동하지 않아 필드와 상태가 어긋난다.
        state.nickname = nickname
        // 빈 입력 에러는 "지우고 엔터"의 결과 — 다시 입력을 시작하면 Empty 상태로 되돌린다.
        state.showsEmptyNicknameError = false
    }

    /// 유효한 닉네임일 때만 변경 요청을 시작한다(엔터·확인 공용 경로). 진행 중이면 중복 실행하지 않는다.
    /// 빈 입력은 요청 대신 안내 문구를 띄운다 — "다 지우고 엔터 누를 시 노출" 이 디자인 정책이다.
    private func beginNicknameChange() {
        if state.nickname.isEmpty {
            state.showsEmptyNicknameError = true
            return
        }
        guard nicknameTask == nil,
              NicknameValidator.errorMessage(for: state.nickname) == nil else { return }
        let groupID = state.groupID
        let nickname = state.nickname
        state.isSavingNickname = true
        nicknameTask = Task {
            await requestNicknameChange(groupID: groupID, nickname: nickname)
            nicknameTask = nil
        }
    }

    /// 서버 요청 후 결과를 다시 `send` 로 되돌려 상태 변이가 `send` 내부에서만 일어나도록 한다.
    /// 제출 시점의 닉네임을 파라미터로 받아, 통신 중 입력이 바뀌어도 실제로 보낸 값과 어긋나지 않게 한다.
    private func requestNicknameChange(groupID: String, nickname: String) async {
        do {
            try await groupUseCase.changeNickname(groupID: groupID, nickname: nickname)
            send(.nicknameChangeFinished(savedNickname: nickname))
        } catch is CancellationError {
            // 화면 이탈로 취소됨 — 실패로 오인하지 않고 조용히 종료.
        } catch {
            send(.nicknameChangeFinished(savedNickname: nil))
        }
    }

    private func applyNicknameChangeResult(_ savedNickname: String?) {
        state.isSavingNickname = false
        // 실패(nil) 안내 디자인 미정(API 도 미정) — 입력은 그대로 두고 다시 제출할 수 있게만 한다.
        guard let savedNickname, case .loaded(let detail) = state.phase else { return }
        state.phase = .loaded(detail.updatingMyNickname(savedNickname))
    }

    private func setExitPopupVisibility(_ exitAction: ExitAction, isPresented: Bool) {
        switch exitAction {
        case .leave: state.isLeavePopupPresented = isPresented
        case .report: state.isReportPopupPresented = isPresented
        case .discardNicknameEdit: state.isDiscardPopupPresented = isPresented
        }
    }

    /// 나가기/신고 요청을 시작한다. 진행 중이면 중복 실행하지 않는다.
    private func beginExit(_ exitAction: ExitAction) {
        // 닉네임 수정 취소는 서버 요청이 없다 — 팝업 확인 즉시 화면을 떠난다.
        if exitAction == .discardNicknameEdit {
            state.completedExit = exitAction
            return
        }
        guard exitTask == nil else { return }
        let groupID = state.groupID
        exitTask = Task {
            await requestExit(groupID: groupID, exitAction: exitAction)
            exitTask = nil
        }
    }

    private func requestExit(groupID: String, exitAction: ExitAction) async {
        do {
            switch exitAction {
            case .leave:
                try await groupUseCase.leave(groupID: groupID)
            case .report:
                // 정책상 신고 접수 = 자동 탈퇴까지 — 별도 leave 호출 없이 한 요청으로 끝난다.
                try await groupUseCase.report(groupID: groupID)
            case .discardNicknameEdit:
                // 서버 요청이 없어 `beginExit` 가 여기까지 오기 전에 끝낸다.
                break
            }
            send(.exitFinished(exitAction))
        } catch is CancellationError {
            // 화면 이탈로 취소됨 — 실패로 오인하지 않고 조용히 종료.
        } catch {
            send(.exitFinished(nil))
        }
    }

    private func cancelAllTasks() {
        loadTask?.cancel()
        loadTask = nil
        nicknameTask?.cancel()
        nicknameTask = nil
        exitTask?.cancel()
        exitTask = nil
    }

    public struct State: Equatable {
        public let groupID: String
        /// 상단 바 타이틀. 상세 응답 전에도 떠 있어야 해서 진입 시점 값으로 시작하고, 응답이 오면 맞춘다.
        public var groupName: String
        public var phase = Phase.idle
        public var nickname = ""
        /// 닉네임을 다 지우고 엔터를 눌렀는지 — 빈 입력 에러는 이때만 띄운다(평소 빈 입력은 Empty 상태).
        public var showsEmptyNicknameError = false
        public var isSavingNickname = false
        public var isLeavePopupPresented = false
        public var isReportPopupPresented = false
        public var isDiscardPopupPresented = false
        /// 나가기/신고/뒤로가기가 끝나 화면을 떠나야 하는 시점의 액션. `nil` 이면 아직 머무른다.
        public var completedExit: ExitAction?

        public init(groupID: String, groupName: String) {
            self.groupID = groupID
            self.groupName = groupName
        }

        public var detail: GroupDetail? {
            if case .loaded(let detail) = phase { return detail }
            return nil
        }

        /// 저장하지 않은 닉네임 수정이 있는지 — 뒤로가기(<) 시 수정 취소 팝업(S-102)의 노출 조건.
        public var hasUnsavedNicknameEdit: Bool {
            guard let detail else { return false }
            return nickname != (detail.myNickname ?? "")
        }

        /// 닉네임 필드 아래 빨간 안내 문구. 빈 입력은 "아직 안 씀"이라 엔터로 제출했을 때만 에러다.
        public var displayedNicknameErrorMessage: String? {
            if nickname.isEmpty {
                return showsEmptyNicknameError ? NicknameValidator.errorMessage(for: "") : nil
            }
            return NicknameValidator.errorMessage(for: nickname)
        }

        /// 키보드 위 확인 버튼 활성 조건 — 닉네임 유효성 검사를 통과하지 못하면 비활성화(S-102).
        public var isNicknameConfirmEnabled: Bool {
            !isSavingNickname && NicknameValidator.errorMessage(for: nickname) == nil
        }
    }

    public enum Phase: Equatable {
        case idle
        case loading
        case loaded(GroupDetail)
        case failed
    }

    /// 사이드메뉴를 떠나게 하는 액션. 확인 팝업 · 확정 요청 · 완료 결과가 모두 이 한 축을 공유한다.
    public enum ExitAction: Equatable {
        /// 그룹 나가기 — 서버 요청 후 G-001 로 복귀한다.
        case leave
        /// 그룹 신고 — 접수되면 서버가 탈퇴까지 처리하고 G-001 로 복귀한다.
        case report
        /// 뒤로가기(<) — 저장하지 않은 닉네임 수정을 버리고 이전 화면으로 돌아간다(S-102).
        case discardNicknameEdit

        /// 화면을 떠난 뒤 2초간 노출할 확인 토스트 문구. 토스트가 없는 액션은 nil.
        public func completionToastMessage(groupName: String) -> String? {
            switch self {
            case .leave: "\(groupName)에서 나왔어요"
            case .report: "신고가 접수되어 운영 정책에 따라 처리됩니다."
            case .discardNicknameEdit: nil
            }
        }
    }

    public enum Intent {
        case screenAppeared
        /// `loadDetail(groupID:)` 완료 결과 — Store 내부에서만 보낸다. `nil` 이면 조회 실패.
        case detailLoadFinished(GroupDetail?)
        case nicknameChanged(String)
        /// 키보드 엔터 또는 키보드 위 확인 버튼 — 닉네임 변경 요청의 유일한 두 입구.
        case nicknameSubmitted
        /// `requestNicknameChange` 완료 결과 — Store 내부에서만 보낸다. `nil` 이면 변경 실패.
        case nicknameChangeFinished(savedNickname: String?)
        /// 나가기/신고/수정 취소 확인 팝업의 표시 여부 — 진입 탭(true)과 그만두기·닫힘(false)이 모두 여기로 온다.
        case exitPopupVisibilityChanged(ExitAction, Bool)
        case exitConfirmed(ExitAction)
        /// `requestExit` 완료 결과 — Store 내부에서만 보낸다. `nil` 이면 요청 실패.
        case exitFinished(ExitAction?)
        case screenDisappeared
    }
}
