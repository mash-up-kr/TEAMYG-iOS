//
//  PreviewSettingDependencies.swift
//  SettingFeature
//
//  Created by 김남수 on 8/17/26.
//

import AuthDomain
import MemberDomain

/// 프리뷰용 목 — 고정 계정을 돌려주고 나머지는 아무것도 하지 않는다.
struct PreviewMemberUseCase: MemberUseCase {
    func fetchMyAccount() async throws -> MemberAccount {
        MemberAccount(id: 0, provider: "Kakao", nickname: "프리뷰닉네임")
    }

    func changeNickname(_ nickname: String) async throws -> String {
        nickname
    }

    func withdraw() async throws {}

    func registerDeviceToken(_ token: String) async throws {}
}

/// 프리뷰용 목 — 모든 인증 동작을 성공으로 흉내낸다.
struct PreviewAuthUseCase: AuthUseCase {
    func loginWithKakao() async throws -> SocialLoginResult { .signedIn }

    func loginWithApple(_ credential: AppleLoginCredential) async throws -> SocialLoginResult {
        .signedIn
    }

    func signup(registrationToken: String, agreements: [TermsAgreement]) async throws {}

    func fetchPolicies() async throws -> [Policy] { [] }

    func logout() async throws {}
}
