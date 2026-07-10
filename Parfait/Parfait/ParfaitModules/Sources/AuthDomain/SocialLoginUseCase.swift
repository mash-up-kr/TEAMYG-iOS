//
//  SocialLoginUseCase.swift
//  AuthDomain
//
//  Created by 김남수 on 7/7/26.
//

/// 소셜 로그인 비즈니스 규칙: credential 획득 → 서버 교환까지 성공해야 로그인 완료.
public protocol SocialLoginUseCase: Sendable {
    /// 카카오: SDK 로그인 → 서버 교환까지 통째로 처리.
    func loginWithKakao() async throws

    /// 애플 등 UI 에서 credential 을 얻는 프로바이더: 교환부터 처리.
    func login(with credential: SocialLoginCredential) async throws
}

public struct SocialLoginUseCaseImpl: SocialLoginUseCase {
    private let authRepository: any AuthRepository

    public init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    public func loginWithKakao() async throws {
        let credential = try await authRepository.loginWithKakao()
        try await authRepository.exchange(credential)
    }

    public func login(with credential: SocialLoginCredential) async throws {
        try await authRepository.exchange(credential)
    }
}
