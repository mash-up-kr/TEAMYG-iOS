//
//  SocialLoginResponseDTO.swift
//  AuthData
//
//  Created by 김남수 on 8/11/26.
//

/// `KakaoLoginResponse`/`AppleLoginResponse` 스키마 대응 — 두 응답의 필드가 같아 하나로 쓴다.
/// `expiresIn` 은 401 기반 갱신 전략이라 받지 않는다 (Core `RefreshedTokensDTO` 와 동일 결정).
struct SocialLoginResponseDTO: Decodable, Sendable {
    /// 기존 회원일 때만 내려온다.
    let accessToken: String?
    let refreshToken: String?
    /// 신규 회원일 때만 내려온다 — 회원가입 완료 요청에 쓴다.
    let registrationToken: String?
    let isNewUser: Bool
}
