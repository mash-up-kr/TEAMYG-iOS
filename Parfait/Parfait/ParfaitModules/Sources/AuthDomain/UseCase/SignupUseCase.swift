//
//  SignupUseCase.swift
//  AuthDomain
//
//  Created by 김남수 on 8/11/26.
//

/// 회원가입 완료 비즈니스 규칙: 약관 동의 전송 → 토큰 발급까지 성공해야 가입 완료.
public protocol SignupUseCase: Sendable {
    /// - Parameter registrationToken: 로그인 교환이 `.signupRequired` 로 돌려준 토큰.
    func signup(registrationToken: String, agreements: [TermsAgreement]) async throws
}

public struct SignupUseCaseImpl: SignupUseCase {
    private let authRepository: any AuthRepository

    public init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    public func signup(registrationToken: String, agreements: [TermsAgreement]) async throws {
        try await authRepository.signup(
            registrationToken: registrationToken,
            agreements: agreements
        )
    }
}
