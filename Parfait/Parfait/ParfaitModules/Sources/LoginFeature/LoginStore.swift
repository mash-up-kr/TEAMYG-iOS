//
//  LoginStore.swift
//  LoginFeature
//
//  Created by 김남수 on 7/3/26.
//

import AuthDomain
import AuthenticationServices
import SwiftUI
import UIComponent

@Observable @MainActor
public final class LoginStore: MVIStore {
    public private(set) var state = State()

    private let socialLoginUseCase: any SocialLoginUseCase
    @ObservationIgnored private var loginTask: Task<Void, Never>?

    public init(socialLoginUseCase: any SocialLoginUseCase) {
        self.socialLoginUseCase = socialLoginUseCase
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .pageChanged(let pageIndex):
            state.currentPageIndex = pageIndex
        case .kakaoLoginTapped:
            guard loginTask == nil else { return }
            loginTask = Task {
                await performKakaoLogin()
                loginTask = nil
            }
        case .appleLoginTapped(let authorizationController):
            guard loginTask == nil else { return }
            loginTask = Task {
                await performAppleLogin(using: authorizationController)
                loginTask = nil
            }
        }
    }

    private func performKakaoLogin() async {
        do {
            try await socialLoginUseCase.loginWithKakao()
            print("카카오 로그인 완료: 서버 교환 응답 수신")
        } catch SocialLoginError.cancelled {
            // 사용자가 로그인 창을 닫음 — 정상 흐름
        } catch {
            print("카카오 로그인 실패: \(error)")
        }
    }

    private func performAppleLogin(using authorizationController: AuthorizationController) async {
        do {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            // 이름·이메일은 최초 승인 때만 내려옴 — 지금 안 받으면 재승인 전까지 못 받음
            request.requestedScopes = [.fullName, .email]

            let result = try await authorizationController.performRequest(request)
            guard case .appleID(let appleIDCredential) = result else { return }
            guard
                let identityTokenData = appleIDCredential.identityToken,
                let identityToken = String(data: identityTokenData, encoding: .utf8)
            else {
                print("Apple 로그인 실패: identityToken 없음")
                return
            }

            let credential = SocialLoginCredential(
                provider: .apple,
                token: identityToken,
                authorizationCode: appleIDCredential.authorizationCode
                    .flatMap { String(data: $0, encoding: .utf8) },
                email: appleIDCredential.email,
                name: appleIDCredential.fullName
                    .map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
            )
            try await socialLoginUseCase.login(with: credential)
            print("Apple 로그인 완료: 서버 교환 응답 수신")
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // 사용자가 로그인 시트를 닫음 — 정상 흐름
        } catch {
            print("Apple 로그인 실패: \(error)")
        }
    }

    public struct State: Equatable {
        public var currentPageIndex = 0
    }

    public enum Intent {
        case pageChanged(Int)
        case kakaoLoginTapped
        case appleLoginTapped(AuthorizationController)
    }
}
