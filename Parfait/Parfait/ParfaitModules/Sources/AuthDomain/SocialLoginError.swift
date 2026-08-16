//
//  SocialLoginError.swift
//  AuthDomain
//
//  Created by 김남수 on 7/6/26.
//

public enum SocialLoginError: Error, Equatable {
    /// 사용자가 로그인 창을 닫음 — 정상 흐름으로 취급.
    case cancelled
    /// SDK 가 토큰·에러 둘 다 주지 않은 비정상 응답.
    case tokenMissing
    /// 서버 응답에 필요한 값(토큰·registrationToken)이 빠진 비정상 응답.
    case invalidServerResponse
}
