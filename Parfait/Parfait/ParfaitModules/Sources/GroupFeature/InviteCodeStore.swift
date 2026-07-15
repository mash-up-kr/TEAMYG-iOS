//
//  InviteCodeStore.swift
//  GroupFeature
//
//  Created by 김남수 on 7/15/26.
//

import GroupDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class InviteCodeStore: MVIStore {
    public nonisolated static let inviteCodeLength = 6

    public private(set) var state = State()

    private let joinGroupUseCase: any JoinGroupUseCase
    @ObservationIgnored private var joinTask: Task<Void, Never>?

    public init(joinGroupUseCase: any JoinGroupUseCase) {
        self.joinGroupUseCase = joinGroupUseCase
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .inviteCodeChanged(let inviteCode):
            state.inviteCode = String(inviteCode.prefix(Self.inviteCodeLength))
        case .inviteCodeFieldTapped:
            guard state.phase == .failed else { return }
            state.inviteCode = ""
            state.phase = .idle
        case .confirmTapped:
            guard joinTask == nil, state.inviteCode.count == Self.inviteCodeLength else { return }
            let inviteCode = state.inviteCode
            state.phase = .loading
            joinTask = Task {
                await requestJoin(inviteCode: inviteCode)
                joinTask = nil
            }
        case .joinSucceeded:
            state.phase = .idle
            state.isSuccessAlertPresented = true
        case .joinFailed:
            state.phase = .failed
        case .successAlertVisibilityChanged(let isPresented):
            state.isSuccessAlertPresented = isPresented
        case .screenDisappeared:
            joinTask?.cancel()
            joinTask = nil
            if state.phase == .loading {
                state.phase = .idle
            }
        }
    }

    /// 서버 요청 후 결과를 다시 `send` 로 되돌려 상태 변이가 `send` 내부에서만 일어나도록 한다.
    /// 제출 시점의 코드를 파라미터로 받아, 통신 중 사용자가 입력을 바꿔도 실제로 보낸 코드와 어긋나지 않게 한다.
    private func requestJoin(inviteCode: String) async {
        do {
            try await joinGroupUseCase.join(inviteCode: inviteCode)
            send(.joinSucceeded)
        } catch is CancellationError {
            // 화면 이탈로 취소됨 — 실패로 오인하지 않고 조용히 종료.
        } catch {
            send(.joinFailed)
        }
    }

    public struct State: Equatable {
        public var inviteCode = ""
        public var phase = Phase.idle
        public var isSuccessAlertPresented = false

        public var isConfirmEnabled: Bool {
            phase != .loading && inviteCode.count == InviteCodeStore.inviteCodeLength
        }
    }

    public enum Phase: Equatable {
        case idle
        case loading
        case failed
    }

    public enum Intent {
        case inviteCodeChanged(String)
        case inviteCodeFieldTapped
        case confirmTapped
        /// `requestJoin()` 완료 결과 — View 가 아니라 Store 내부에서만 보낸다.
        case joinSucceeded
        case joinFailed
        case successAlertVisibilityChanged(Bool)
        case screenDisappeared
    }
}
