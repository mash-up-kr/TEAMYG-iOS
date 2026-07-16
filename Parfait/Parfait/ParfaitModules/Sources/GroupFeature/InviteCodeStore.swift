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
    nonisolated static let inviteCodeLength = 6

    public private(set) var state = State()

    private let joinGroupUseCase: any JoinGroupUseCase
    @ObservationIgnored private var joinTask: Task<Void, Never>?

    public init(joinGroupUseCase: any JoinGroupUseCase) {
        self.joinGroupUseCase = joinGroupUseCase
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .inviteCodeChanged(let inviteCode):
            state.inviteCode = String(
                Self.normalizedInviteCode(from: inviteCode).prefix(Self.inviteCodeLength)
            )
        case .inviteCodeFieldTapped:
            guard state.isFailed else { return }
            state.inviteCode = ""
            state.phase = .idle
        case .pasted(let pastedString):
            applyPastedString(pastedString)
        case .confirmTapped:
            beginJoinRequest()
        case .joinSucceeded:
            state.phase = .idle
            state.isSuccessAlertPresented = true
        case .joinFailed(let joinError):
            state.phase = .failed(joinError)
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

    /// 6자 입력 완료 상태에서만 참여 요청을 시작한다. 진행 중이면 중복 실행하지 않는다.
    private func beginJoinRequest() {
        guard joinTask == nil, state.inviteCode.count == Self.inviteCodeLength else { return }
        let inviteCode = state.inviteCode
        state.phase = .loading
        joinTask = Task {
            await requestJoin(inviteCode: inviteCode)
            joinTask = nil
        }
    }

    /// 붙여넣은 문자열이 공유 형식이면 초대코드를 채운다 — 실패 상태였다면 함께 해제.
    private func applyPastedString(_ pastedString: String) {
        guard let inviteCode = Self.inviteCode(fromPastedString: pastedString) else { return }
        state.inviteCode = inviteCode
        if state.isFailed {
            state.phase = .idle
        }
    }

    /// 초대코드로 허용되는 문자만 남긴다 — 소문자는 대문자로 승격, 나머지(붙여넣기 포함)는 버린다.
    private static func normalizedInviteCode(from rawString: some StringProtocol) -> String {
        rawString.uppercased().filter { ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
    }

    /// 클립보드 공유 형식 "parfait <코드>" 문자열에서 초대코드를 추출한다. 형식이 아니면 nil.
    /// prefix 뒤 구분 문자(공백·괄호 등)는 무엇이든 허용하고, 남은 영숫자가 정확히 6자일 때만 인정.
    private static func inviteCode(fromPastedString pastedString: String) -> String? {
        let trimmed = pastedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("parfait") else { return nil }
        let code = normalizedInviteCode(from: trimmed.dropFirst("parfait".count))
        return code.count == inviteCodeLength ? code : nil
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
            send(.joinFailed(error as? JoinGroupError ?? .unknown))
        }
    }

    public struct State: Equatable {
        public var inviteCode = ""
        public var phase = Phase.idle
        public var isSuccessAlertPresented = false

        public var isConfirmEnabled: Bool {
            phase != .loading && inviteCode.count == InviteCodeStore.inviteCodeLength
        }

        /// `phase == .failed` 일 때의 실패 사유 — View 렌더링용 파생 값.
        public var joinError: JoinGroupError? {
            if case .failed(let joinError) = phase { return joinError }
            return nil
        }

        public var isFailed: Bool { joinError != nil }
    }

    public enum Phase: Equatable {
        case idle
        case loading
        case failed(JoinGroupError)
    }

    public enum Intent {
        case inviteCodeChanged(String)
        case inviteCodeFieldTapped
        /// 클립보드 붙여넣기 버튼으로 받은 원본 문자열 — 형식 검증·추출은 Store 가 한다.
        case pasted(String)
        case confirmTapped
        /// `requestJoin()` 완료 결과 — View 가 아니라 Store 내부에서만 보낸다.
        case joinSucceeded
        case joinFailed(JoinGroupError)
        case successAlertVisibilityChanged(Bool)
        case screenDisappeared
    }
}
