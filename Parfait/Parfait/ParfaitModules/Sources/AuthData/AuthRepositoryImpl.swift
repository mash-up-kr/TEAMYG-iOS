//
//  AuthRepositoryImpl.swift
//  AuthData
//
//  Created by 김남수 on 7/6/26.
//

import AuthDomain
import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

/// AuthRepository 구현체 — 카카오는 SDK 로 로그인까지, 서버 교환은 두 프로바이더 공용.
/// 카카오톡 앱이 있으면 앱 로그인, 없으면 카카오계정 웹 로그인으로 폴백.
public struct AuthRepositoryImpl: AuthRepository {

    public init() {}

    @MainActor
    public func loginWithKakao() async throws -> SocialLoginCredential {
        let accessToken: String = try await withCheckedThrowingContinuation { continuation in
            let completion: (OAuthToken?, Error?) -> Void = { token, error in
                if let error {
                    if case SdkError.ClientFailed(reason: .Cancelled, errorMessage: _) = error {
                        continuation.resume(throwing: SocialLoginError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else if let token {
                    continuation.resume(returning: token.accessToken)
                } else {
                    continuation.resume(throwing: SocialLoginError.tokenMissing)
                }
            }
            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: completion)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: completion)
            }
        }
        return SocialLoginCredential(provider: .kakao, token: accessToken)
    }

    public func exchange(_ credential: SocialLoginCredential) async throws {
        // ponytail: 서버 API 스펙 미정 — 확정 시 여기에 URLSession 호출 채움.
        // 네트워크는 AuthData 안에서 시작, 두 번째 소비자 생기면 Core 로 승격 (2026-07-07 팀 결정).
        print(
            "서버 교환 스텁: provider=\(credential.provider.rawValue),",
            "email=\(credential.email != nil), name=\(credential.name != nil)"
        )
    }
}
