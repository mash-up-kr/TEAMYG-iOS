//
//  TermsStore.swift
//  LoginFeature
//
//  Created by 김남수 on 7/14/26.
//

import AuthDomain
import Common
import SwiftUI
import UIComponent

@Observable @MainActor
public final class TermsStore: MVIStore {
    public private(set) var state = State()

    /// 일회성 이벤트 채널(네비게이션 등). state 에 넣으면 재진입 시 재발화되므로 분리. (mvi.md)
    let events: AsyncStream<Event>
    @ObservationIgnored private let eventContinuation: AsyncStream<Event>.Continuation

    /// 로그인이 `.signupRequired` 로 돌려준 가입 토큰 — 회원가입 완료 요청에 실린다.
    private let registrationToken: String
    private let policiesUseCase: any PoliciesUseCase
    private let signupUseCase: any SignupUseCase
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var signupTask: Task<Void, Never>?

    public init(
        registrationToken: String,
        policiesUseCase: any PoliciesUseCase,
        signupUseCase: any SignupUseCase
    ) {
        self.registrationToken = registrationToken
        self.policiesUseCase = policiesUseCase
        self.signupUseCase = signupUseCase
        (events, eventContinuation) = AsyncStream.makeStream()
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .retryTapped:
            beginLoad()
        case .screenDisappeared:
            loadTask?.cancel()
            loadTask = nil
            signupTask?.cancel()
            signupTask = nil
        case .policiesLoaded(let policies):
            state.phase = .loaded(policies)
        case .loadFailed:
            state.phase = .failed
        case .allAgreementTapped:
            // 하나라도 미동의면 전체 동의, 이미 전체 동의면 전체 해제.
            state.agreed = state.isAllAgreed ? [] : Set(state.policies.map(\.id))
        case .itemTapped(let policy):
            toggleAgreement(policy)
        case .confirmTapped:
            beginSignup()
        case .signupSucceeded:
            state.signupPhase = .idle
            eventContinuation.yield(.signupCompleted)
        case .signupFailed:
            state.signupPhase = .failed
        case .signupFailureAcknowledged:
            clearSignupFailure()
        }
    }

    private func toggleAgreement(_ policy: Policy) {
        if state.agreed.contains(policy.id) {
            state.agreed.remove(policy.id)
        } else {
            state.agreed.insert(policy.id)
        }
    }

    private func clearSignupFailure() {
        guard state.signupPhase == .failed else { return }
        state.signupPhase = .idle
    }

    /// 진행 중이거나 이미 로드됐으면 다시 요청하지 않는다 — 재진입 시 동의 상태 유지.
    private func beginLoad() {
        guard loadTask == nil else { return }
        if case .loaded = state.phase { return }
        state.phase = .loading
        loadTask = Task {
            do {
                let policies = try await policiesUseCase.fetchPolicies()
                send(.policiesLoaded(policies))
            } catch is CancellationError {
                // 화면 이탈로 취소됨 — 실패로 오인하지 않는다.
            } catch {
                send(.loadFailed)
            }
            loadTask = nil
        }
    }

    /// 필수 약관 동의가 끝났을 때만 회원가입을 시작한다. 진행 중이면 중복 실행하지 않는다.
    /// 제출 시점의 동의 상태를 캡처해, 통신 중 사용자가 값을 바꿔도 실제로 보낸 것과 어긋나지 않게 한다.
    private func beginSignup() {
        guard signupTask == nil, state.canProceed else { return }
        state.signupPhase = .submitting
        let agreements = state.agreements
        signupTask = Task {
            do {
                try await signupUseCase.signup(
                    registrationToken: registrationToken,
                    agreements: agreements
                )
                send(.signupSucceeded)
            } catch is CancellationError {
                // 화면 이탈로 취소됨 — 실패로 오인하지 않는다.
            } catch {
                YGLogger.error("회원가입 실패: \(error)")
                send(.signupFailed)
            }
            signupTask = nil
        }
    }

    public struct State: Equatable {
        var phase = Phase.idle

        /// 회원가입 완료 요청 진행 상태.
        var signupPhase = SignupPhase.idle

        /// 동의한 약관 id 집합.
        var agreed: Set<Int> = []

        var policies: [Policy] {
            if case .loaded(let policies) = phase { return policies }
            return []
        }

        /// 전체 약관 동의 여부.
        var isAllAgreed: Bool {
            !policies.isEmpty && policies.allSatisfy { agreed.contains($0.id) }
        }

        /// 다음 단계 진행 가능 = 약관이 로드됐고 필수 약관 모두 동의, 가입 요청이 진행 중이 아님.
        var canProceed: Bool {
            signupPhase != .submitting
                && !policies.isEmpty
                && policies.filter(\.isRequired).allSatisfy { agreed.contains($0.id) }
        }

        /// 회원가입 완료 요청(`SignupUseCase`)에 실을 항목별 동의 여부.
        var agreements: [TermsAgreement] {
            policies.map { TermsAgreement(termsId: $0.id, agreed: agreed.contains($0.id)) }
        }

        func isAgreed(_ policy: Policy) -> Bool {
            agreed.contains(policy.id)
        }
    }

    public enum Phase: Equatable {
        case idle
        case loading
        case loaded([Policy])
        case failed
    }

    public enum SignupPhase: Equatable {
        case idle
        case submitting
        case failed
    }

    public enum Intent {
        case screenAppeared
        case screenDisappeared
        case retryTapped
        /// 로드 결과 — View 가 아니라 Store 내부에서만 보낸다.
        case policiesLoaded([Policy])
        case loadFailed
        case allAgreementTapped
        case itemTapped(Policy)
        case confirmTapped
        /// 가입 요청 결과 — View 가 아니라 Store 내부에서만 보낸다.
        case signupSucceeded
        case signupFailed
        case signupFailureAcknowledged
    }

    /// 뷰가 소비하는 일회성 이벤트.
    enum Event: Sendable {
        /// 회원가입 완료(토큰 저장까지 끝) — 다음 화면으로 이동.
        case signupCompleted
    }
}
