//
//  AuthRepository.swift
//  AuthDomain
//
//  Created by 김남수 on 7/6/26.
//

public protocol AuthRepository: Sendable {
    func loginWithKakao() async throws -> SocialLoginToken
}
