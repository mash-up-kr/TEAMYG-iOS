//
//  TermsStore.swift
//  LoginFeature
//
//  Created by 김남수 on 7/14/26.
//

import AuthDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class TermsStore: MVIStore {
    public private(set) var state = State()

    private let policiesUseCase: any PoliciesUseCase
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    public init(policiesUseCase: any PoliciesUseCase) {
        self.policiesUseCase = policiesUseCase
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .retryTapped:
            beginLoad()
        case .screenDisappeared:
            loadTask?.cancel()
            loadTask = nil
        case .policiesLoaded(let policies):
            state.phase = .loaded(policies)
        case .loadFailed:
            state.phase = .failed
        case .allAgreementTapped:
            // 하나라도 미동의면 전체 동의, 이미 전체 동의면 전체 해제.
            state.agreed = state.isAllAgreed ? [] : Set(state.policies.map(\.id))
        case .itemTapped(let policy):
            if state.agreed.contains(policy.id) {
                state.agreed.remove(policy.id)
            } else {
                state.agreed.insert(policy.id)
            }
        }
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

    public struct State: Equatable {
        var phase = Phase.idle

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

        /// 다음 단계 진행 가능 = 약관이 로드됐고 필수 약관 모두 동의.
        var canProceed: Bool {
            !policies.isEmpty && policies.filter(\.isRequired).allSatisfy { agreed.contains($0.id) }
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

    public enum Intent {
        case screenAppeared
        case screenDisappeared
        case retryTapped
        /// 로드 결과 — View 가 아니라 Store 내부에서만 보낸다.
        case policiesLoaded([Policy])
        case loadFailed
        case allAgreementTapped
        case itemTapped(Policy)
    }
}
