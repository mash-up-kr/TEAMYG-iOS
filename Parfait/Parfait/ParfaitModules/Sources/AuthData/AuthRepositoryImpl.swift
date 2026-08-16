//
//  AuthRepositoryImpl.swift
//  AuthData
//
//  Created by 김남수 on 7/6/26.
//

import AuthDomain
import Common
import Core
import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

/// AuthRepository 구현체 — 카카오는 SDK 로 로그인까지, 서버 교환·회원가입은 두 프로바이더 공용.
/// 카카오톡 앱이 있으면 앱 로그인, 없으면 카카오계정 웹 로그인으로 폴백.
public struct AuthRepositoryImpl: AuthRepository {
    private let networkClient: any NetworkClient
    // KakaoSDKAuth 의 TokenManager 와 이름이 겹쳐 모듈을 명시한다
    private let tokenManager: Core::TokenManager

    public init(networkClient: any NetworkClient, tokenManager: Core::TokenManager) {
        self.networkClient = networkClient
        self.tokenManager = tokenManager
    }

    @MainActor
    public func loginWithKakao() async throws -> SocialLoginResult {
        // 서버가 OIDC idToken + nonce 를 검증하므로 accessToken 이 아니라 idToken 을 쓴다.
        let nonce = UUID().uuidString
        let idToken: String = try await withCheckedThrowingContinuation { continuation in
            let completion: (OAuthToken?, Error?) -> Void = { token, error in
                if let error {
                    if case SdkError.ClientFailed(reason: .Cancelled, errorMessage: _) = error {
                        continuation.resume(throwing: SocialLoginError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else if let idToken = token?.idToken {
                    continuation.resume(returning: idToken)
                } else {
                    // idToken 없음 = 카카오 콘솔에서 OpenID Connect 미활성 가능성
                    continuation.resume(throwing: SocialLoginError.tokenMissing)
                }
            }
            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(nonce: nonce, completion: completion)
            } else {
                UserApi.shared.loginWithKakaoAccount(nonce: nonce, completion: completion)
            }
        }
        YGLogger.log("카카오 SDK 로그인 성공 — 수신 값\nidToken: \(idToken)\nnonce: \(nonce)")
        let response: SocialLoginResponseDTO = try await networkClient.request(
            KakaoLoginEndpoint(idToken: idToken, nonce: nonce)
        )
        return try await finishLogin(with: response)
    }

    public func loginWithApple(_ credential: AppleLoginCredential) async throws -> SocialLoginResult {
        let response: SocialLoginResponseDTO = try await networkClient.request(
            AppleLoginEndpoint(identityToken: credential.identityToken, nonce: credential.nonce)
        )
        return try await finishLogin(with: response)
    }

    public func signup(registrationToken: String, agreements: [TermsAgreement]) async throws {
        let response: SignupResponseDTO = try await networkClient.request(
            SignupEndpoint(registrationToken: registrationToken, agreements: agreements)
        )
        await tokenManager.update(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )
    }

    public func fetchPolicies() async throws -> [Policy] {
        let response: PolicyResponseDTO = try await networkClient.request(PoliciesEndpoint())
        return response.policies.map {
            Policy(id: $0.termsId, title: $0.title, url: $0.url, isRequired: $0.required)
        }
    }
}

private extension AuthRepositoryImpl {
    /// 로그인 응답 공통 처리 — 기존 회원이면 토큰 저장, 신규 회원이면 가입 토큰 반환.
    func finishLogin(with response: SocialLoginResponseDTO) async throws -> SocialLoginResult {
        if response.isNewUser {
            guard let registrationToken = response.registrationToken else {
                throw SocialLoginError.invalidServerResponse
            }
            return .signupRequired(registrationToken: registrationToken)
        }
        guard
            let accessToken = response.accessToken,
            let refreshToken = response.refreshToken
        else {
            throw SocialLoginError.invalidServerResponse
        }
        await tokenManager.update(accessToken: accessToken, refreshToken: refreshToken)
        return .signedIn
    }
}
