//
//  AuthRepository.swift
//  AuthDomain
//
//  Created by 김남수 on 7/6/26.
//

public protocol AuthRepository: Sendable {
    /// 카카오: SDK 로그인 → 서버 교환까지 처리.
    /// 기존 회원이면 토큰 저장까지 마치고 `.signedIn`, 신규 회원이면 `.signupRequired` 를 돌려준다.
    func loginWithKakao() async throws -> SocialLoginResult

    /// 애플: UI 에서 얻은 credential 을 서버로 보내 로그인을 완료한다. 결과 규칙은 카카오와 같다.
    func loginWithApple(_ credential: AppleLoginCredential) async throws -> SocialLoginResult

    /// 약관 동의를 보내 회원가입을 완료하고 토큰을 저장한다.
    /// - Parameter registrationToken: 로그인이 `.signupRequired` 로 돌려준 토큰.
    func signup(registrationToken: String, agreements: [TermsAgreement]) async throws
}
