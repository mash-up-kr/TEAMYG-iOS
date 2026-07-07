//
//  AuthRepository.swift
//  AuthDomain
//
//  Created by 김남수 on 7/6/26.
//

public protocol AuthRepository: Sendable {
    /// 카카오 SDK 로그인 → 서버로 보낼 credential 획득.
    func loginWithKakao() async throws -> SocialLoginCredential

    /// credential 을 서버로 보내 로그인을 완료한다.
    /// 응답 스펙 미정 — 반환 타입은 백엔드 스펙 확정 시 추가.
    func exchange(_ credential: SocialLoginCredential) async throws
}
