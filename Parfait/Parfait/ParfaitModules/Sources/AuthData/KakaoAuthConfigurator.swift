//
//  KakaoAuthConfigurator.swift
//  AuthData
//
//  Created by 김남수 on 7/6/26.
//

import Foundation
import KakaoSDKAuth
import KakaoSDKCommon

/// App 레이어가 Kakao SDK 를 직접 import 하지 않도록 초기화·URL 처리를 감싼다.
public enum KakaoAuthConfigurator {

    /// 앱 시작 시 1회 호출. 키가 비어 있으면 초기화를 건너뛴다 — 카카오 로그인만 비활성.
    @MainActor
    public static func initialize(appKey: String) {
        guard !appKey.isEmpty else {
            print("KAKAO_NATIVE_APP_KEY 미설정 — 카카오 로그인 비활성 (Config/Secrets.xcconfig 확인)")
            return
        }
        KakaoSDK.initSDK(appKey: appKey)
    }

    /// 카카오 OAuth 리다이렉트 URL 처리. 카카오 로그인 URL 이 아니면 false.
    @MainActor
    @discardableResult
    public static func handleOpenURL(_ url: URL) -> Bool {
        guard AuthApi.isKakaoTalkLoginUrl(url) else { return false }
        return AuthController.handleOpenUrl(url: url)
    }
}
