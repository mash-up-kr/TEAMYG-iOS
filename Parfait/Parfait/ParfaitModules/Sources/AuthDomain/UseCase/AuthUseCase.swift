//
//  AuthUseCase.swift
//  AuthDomain
//
//  Created by 김남수 on 8/17/26.
//

/// 인증 유스케이스 — 소셜 로그인·회원가입·약관 조회.
public protocol AuthUseCase: Sendable {
    /// 카카오: SDK 로그인 → 서버 교환까지 통째로 처리.
    func loginWithKakao() async throws -> SocialLoginResult

    /// 애플: UI(AuthorizationController)에서 얻은 credential 로 서버 교환을 처리.
    func loginWithApple(_ credential: AppleLoginCredential) async throws -> SocialLoginResult

    /// - Parameter registrationToken: 로그인 교환이 `.signupRequired` 로 돌려준 토큰.
    func signup(registrationToken: String, agreements: [TermsAgreement]) async throws

    /// 약관 목록 조회 — 약관 동의 화면·설정 화면 공용.
    func fetchPolicies() async throws -> [Policy]
}

public struct AuthUseCaseImpl: AuthUseCase {
    private let authRepository: any AuthRepository

    public init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    public func loginWithKakao() async throws -> SocialLoginResult {
        try await authRepository.loginWithKakao()
    }

    public func loginWithApple(_ credential: AppleLoginCredential) async throws -> SocialLoginResult {
        try await authRepository.loginWithApple(credential)
    }

    public func signup(registrationToken: String, agreements: [TermsAgreement]) async throws {
        try await authRepository.signup(registrationToken: registrationToken, agreements: agreements)
    }

    public func fetchPolicies() async throws -> [Policy] {
        try await authRepository.fetchPolicies()
    }
}
