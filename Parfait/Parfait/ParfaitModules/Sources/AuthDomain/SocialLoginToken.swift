//
//  SocialLoginToken.swift
//  AuthDomain
//
//  Created by 김남수 on 7/6/26.
//

/// 소셜 로그인 성공 결과. 서버 교환 전까지는 accessToken 만 필요.
public struct SocialLoginToken: Equatable, Sendable {
    public let accessToken: String

    public init(accessToken: String) {
        self.accessToken = accessToken
    }
}
