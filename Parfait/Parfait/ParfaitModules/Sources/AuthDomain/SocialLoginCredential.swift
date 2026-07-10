//
//  SocialLoginCredential.swift
//  AuthDomain
//
//  Created by 김남수 on 7/7/26.
//

public enum SocialProvider: String, Sendable {
    case kakao
    case apple
}

/// 소셜 로그인 결과를 서버로 보내기 위한 그릇.
/// 프로바이더에 따라 토큰 외에 이메일·이름이 실릴 수 있다 (애플은 최초 승인 때만 제공).
public struct SocialLoginCredential: Equatable, Sendable {
    public let provider: SocialProvider
    /// kakao: accessToken / apple: identityToken(JWT)
    public let token: String
    /// apple 전용 — 서버가 애플 검증에 사용
    public let authorizationCode: String?
    public let email: String?
    public let name: String?

    public init(
        provider: SocialProvider,
        token: String,
        authorizationCode: String? = nil,
        email: String? = nil,
        name: String? = nil
    ) {
        self.provider = provider
        self.token = token
        self.authorizationCode = authorizationCode
        self.email = email
        self.name = name
    }
}
