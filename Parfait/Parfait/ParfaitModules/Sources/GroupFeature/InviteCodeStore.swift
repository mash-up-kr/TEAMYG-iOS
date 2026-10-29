//
//  InviteCodeStore.swift
//  GroupFeature
//
//  Created by 김남수 on 7/15/26.
//

import Common
import GroupDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class InviteCodeStore: MVIStore {
    nonisolated static let inviteCodeLength = 6

    public private(set) var state = State()

    private let groupUseCase: any GroupUseCase
    @ObservationIgnored private var joinTask: Task<Void, Never>?
    private let logAnalyticsEvent: AnalyticsEventLogger

    /// - Parameter prefilledCode: 미리 채울 초대코드(초대 링크 진입). 입력과 같은 규칙으로 정규화한다.
    public init(
        groupUseCase: any GroupUseCase,
        logAnalyticsEvent: @escaping AnalyticsEventLogger,
        prefilledCode: String = ""
    ) {
        self.groupUseCase = groupUseCase
        self.logAnalyticsEvent = logAnalyticsEvent
        state.inviteCode = String(Self.normalizedInviteCode(from: prefilledCode).prefix(Self.inviteCodeLength))
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            logAnalyticsEvent(.screenView(.groupJoin))
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
        case .joinSucceeded(let joinedGroup):
            logAnalyticsEvent(.groupListJoined)
            state.phase = .idle
            state.joinedGroup = joinedGroup
        case .joinFailed(let joinError):
            state.phase = .failed(joinError)
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
        // 진입·복귀마다 클립보드를 자동으로 읽으므로, 초대코드를 실제로 채웠을 때만 집계한다.
        guard let inviteCode = Self.inviteCode(fromPastedString: pastedString) else { return }
        logAnalyticsEvent(.groupListInviteCodePasted)
        state.inviteCode = inviteCode
        if state.isFailed {
            state.phase = .idle
        }
    }

    /// 초대코드로 허용되는 문자만 남긴다 — 소문자는 대문자로 승격, 나머지(붙여넣기 포함)는 버린다.
    private static func normalizedInviteCode(from rawString: some StringProtocol) -> String {
        rawString.uppercased().filter { ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
    }

    /// 공유 문구("...가볼까요?\nhttps://parfait-app.store/link?inviteCode=KS479J") 맨 뒤 6자를 초대코드로 본다.
    /// 앞 문구 형식은 검사하지 않으므로 코드만 복사해 붙여넣어도 인정되고,
    /// 마지막 6자에 영숫자가 아닌 문자가 섞이면 nil.
    private static func inviteCode(fromPastedString pastedString: String) -> String? {
        let trimmed = pastedString.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = normalizedInviteCode(from: trimmed.suffix(inviteCodeLength))
        return code.count == inviteCodeLength ? code : nil
    }

    /// 서버 요청 후 결과를 다시 `send` 로 되돌려 상태 변이가 `send` 내부에서만 일어나도록 한다.
    /// 제출 시점의 코드를 파라미터로 받아, 통신 중 사용자가 입력을 바꿔도 실제로 보낸 코드와 어긋나지 않게 한다.
    private func requestJoin(inviteCode: String) async {
        do {
            let joinedGroup = try await groupUseCase.join(inviteCode: inviteCode)
            send(.joinSucceeded(joinedGroup))
        } catch is CancellationError {
            // 화면 이탈로 취소됨 — 실패로 오인하지 않고 조용히 종료.
        } catch {
            send(.joinFailed(error as? JoinGroupError ?? .unknown))
        }
    }

    public struct State: Equatable {
        public var inviteCode = ""
        public var phase = Phase.idle
        public var joinedGroup: JoinedGroup?

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
        case screenAppeared
        case inviteCodeChanged(String)
        case inviteCodeFieldTapped
        /// 진입·복귀 때 클립보드에서 읽은 원본 문자열 — 형식 검증·추출은 Store 가 한다.
        case pasted(String)
        case confirmTapped
        /// `requestJoin()` 완료 결과 — View 가 아니라 Store 내부에서만 보낸다.
        case joinSucceeded(JoinedGroup)
        case joinFailed(JoinGroupError)
        case screenDisappeared
    }
}
