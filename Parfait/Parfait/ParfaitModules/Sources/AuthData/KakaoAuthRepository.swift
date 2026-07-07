//
//  KakaoAuthRepository.swift
//  AuthData
//
//  Created by 김남수 on 7/6/26.
//

import AuthDomain
import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

/// Kakao SDK 기반 AuthRepository 구현.
/// 카카오톡 앱이 있으면 앱 로그인, 없으면 카카오계정 웹 로그인으로 폴백.
public struct KakaoAuthRepository: AuthRepository {

    public init() {}

    @MainActor
    public func loginWithKakao() async throws -> SocialLoginToken {
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
        return SocialLoginToken(accessToken: accessToken)
    }
}
