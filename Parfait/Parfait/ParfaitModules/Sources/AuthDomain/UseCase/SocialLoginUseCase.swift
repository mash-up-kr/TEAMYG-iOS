//
//  SocialLoginUseCase.swift
//  AuthDomain
//
//  Created by 김남수 on 7/7/26.
//

/// 소셜 로그인 비즈니스 규칙: credential 획득 → 서버 교환까지 성공해야 로그인 완료.
public protocol SocialLoginUseCase: Sendable {
    /// 카카오: SDK 로그인 → 서버 교환까지 통째로 처리.
    func loginWithKakao() async throws -> SocialLoginResult

    /// 애플: UI(AuthorizationController)에서 얻은 credential 로 서버 교환을 처리.
    func loginWithApple(_ credential: AppleLoginCredential) async throws -> SocialLoginResult
}

public struct SocialLoginUseCaseImpl: SocialLoginUseCase {
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
}
