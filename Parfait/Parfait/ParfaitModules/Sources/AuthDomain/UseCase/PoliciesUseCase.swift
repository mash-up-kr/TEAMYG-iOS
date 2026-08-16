//
//  PoliciesUseCase.swift
//  AuthDomain
//
//  Created by 김남수 on 8/12/26.
//

/// 약관 목록 조회 — 약관 동의 화면·설정 화면 공용.
public protocol PoliciesUseCase: Sendable {
    func fetchPolicies() async throws -> [Policy]
}

public struct PoliciesUseCaseImpl: PoliciesUseCase {
    private let authRepository: any AuthRepository

    public init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    public func fetchPolicies() async throws -> [Policy] {
        try await authRepository.fetchPolicies()
    }
}
