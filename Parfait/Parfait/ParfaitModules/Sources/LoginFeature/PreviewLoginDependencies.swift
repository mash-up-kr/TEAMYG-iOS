//
//  PreviewLoginDependencies.swift
//  LoginFeature
//
//  Created by 김남수 on 8/17/26.
//

import AuthDomain
import Foundation

/// 프리뷰 전용 스텁 — SDK·서버 호출 없이 즉시 성공.
struct PreviewAuthUseCase: AuthUseCase {
    func loginWithKakao() async throws -> SocialLoginResult { .signedIn }

    func loginWithApple(_ credential: AppleLoginCredential) async throws -> SocialLoginResult {
        .signedIn
    }

    func signup(registrationToken: String, agreements: [TermsAgreement]) async throws {}

    func fetchPolicies() async throws -> [Policy] {
        [
            Policy(
                id: 1,
                title: "서비스 이용약관",
                url: URL(string: "https://example.com")!,
                isRequired: true
            ),
            Policy(
                id: 2,
                title: "개인정보 처리방침",
                url: URL(string: "https://example.com")!,
                isRequired: true
            )
        ]
    }
}
