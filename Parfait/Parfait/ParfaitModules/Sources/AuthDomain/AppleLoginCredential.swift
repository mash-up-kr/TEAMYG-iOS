//
//  AppleLoginCredential.swift
//  AuthDomain
//
//  Created by 김남수 on 8/11/26.
//

/// 애플 로그인 결과를 서버로 보내기 위한 그릇 — 획득에 UI 가 필요해 화면(LoginFeature)이 만들어 넘긴다.
/// 카카오는 credential 획득이 Data 레이어(SDK) 안에서 끝나 별도 타입이 없다.
public struct AppleLoginCredential: Equatable, Sendable {
    /// 애플이 발급한 identityToken(JWT).
    public let identityToken: String
    /// 토큰 재생 공격 방지 값 — 로그인 요청에 넣은 것과 같은 문자열을 서버가 검증한다.
    public let nonce: String
    /// 서버가 애플 검증에 사용.
    public let authorizationCode: String

    public init(identityToken: String, nonce: String, authorizationCode: String) {
        self.identityToken = identityToken
        self.nonce = nonce
        self.authorizationCode = authorizationCode
    }
}
