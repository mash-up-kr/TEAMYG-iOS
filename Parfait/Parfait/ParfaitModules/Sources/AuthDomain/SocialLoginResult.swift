//
//  SocialLoginResult.swift
//  AuthDomain
//
//  Created by 김남수 on 8/11/26.
//

/// 서버 로그인 교환 결과.
public enum SocialLoginResult: Equatable, Sendable {
    /// 기존 회원 — 토큰 저장까지 끝난 상태.
    case signedIn
    /// 신규 회원 — 약관 동의 후 회원가입 완료(signup)에 이 토큰을 넘긴다.
    case signupRequired(registrationToken: String)
}
