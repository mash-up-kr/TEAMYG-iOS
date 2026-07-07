//
//  LoginStore.swift
//  LoginFeature
//
//  Created by 김남수 on 7/3/26.
//

import AuthDomain
import AuthenticationServices
import Observation
import SwiftUI // AuthorizationController 는 AuthenticationServices+SwiftUI 크로스 임포트 타입
import UIComponent

@Observable @MainActor
public final class LoginStore: MVIStore {
    public private(set) var state = State()

    private let authRepository: any AuthRepository
    @ObservationIgnored private var loginTask: Task<Void, Never>?

    public init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
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
            let token = try await authRepository.loginWithKakao()
            // ponytail: 서버 인증 미구현 — 토큰 교환은 백엔드 연동 시 (애플 로그인과 동일)
            print("카카오 로그인 성공: accessToken 수신=\(!token.accessToken.isEmpty)")
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
            guard case .appleID(let credential) = result else { return }
            // ponytail: 서버 인증 미구현 — identityToken/authorizationCode 교환은 AuthDomain/AuthData 연동 시 이관
            print("Apple 로그인 성공: user=\(credential.user), token=\(credential.identityToken != nil)")
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
