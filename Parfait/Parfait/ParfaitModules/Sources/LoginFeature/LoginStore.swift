//
//  LoginStore.swift
//  LoginFeature
//
//  Created by 김남수 on 7/3/26.
//

import AuthDomain
import AuthenticationServices
import Common
import CryptoKit
import SwiftUI
import UIComponent

@Observable @MainActor
public final class LoginStore: MVIStore {
    public private(set) var state = State()

    /// 일회성 이벤트 채널(네비게이션 등). state 에 넣으면 재진입 시 재발화되므로 분리. (mvi.md)
    let events: AsyncStream<Event>
    @ObservationIgnored private let eventContinuation: AsyncStream<Event>.Continuation

    private let socialLoginUseCase: any SocialLoginUseCase
    @ObservationIgnored private var loginTask: Task<Void, Never>?

    public init(socialLoginUseCase: any SocialLoginUseCase) {
        self.socialLoginUseCase = socialLoginUseCase
        (events, eventContinuation) = AsyncStream.makeStream()
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
            let result = try await socialLoginUseCase.loginWithKakao()
            YGLogger.log("카카오 로그인 완료: \(result)")
            handle(result)
        } catch SocialLoginError.cancelled {
            // 사용자가 로그인 창을 닫음 — 정상 흐름
        } catch {
            YGLogger.error("카카오 로그인 실패: \(error)")
        }
    }

    private func performAppleLogin(using authorizationController: AuthorizationController) async {
        do {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            // 스코프는 최초 승인 때만 반영됨. 이메일은 .email 스코프 덕에 identityToken 클레임으로
            // 서버에 전달되고, 이름은 현재 서버 수신 스펙이 없어 보내지 않는다.
            request.requestedScopes = [.fullName, .email]
            // 서버가 identityToken 의 nonce claim 과 함께 보낸 nonce 를 대조해 재생 공격을 막는다.
            // 애플에는 SHA256 해시를 보내고(identityToken 의 nonce claim 에 해시가 실림), 서버에는 원본을 보낸다.
            let nonce = UUID().uuidString
            request.nonce = SHA256.hash(data: Data(nonce.utf8))
                .map { String(format: "%02x", $0) }
                .joined()

            let result = try await authorizationController.performRequest(request)
            guard case .appleID(let appleIDCredential) = result else { return }
            guard
                let identityTokenData = appleIDCredential.identityToken,
                let identityToken = String(data: identityTokenData, encoding: .utf8)
            else {
                YGLogger.error("Apple 로그인 실패: identityToken 없음")
                return
            }
            YGLogger.log(
                """
                Apple 로그인 성공 — 수신 값
                identityToken: \(identityToken)
                nonce: \(nonce)
                email: \(appleIDCredential.email ?? "-")
                fullName: \(appleIDCredential.fullName?.formatted() ?? "-")
                """
            )

            let credential = AppleLoginCredential(identityToken: identityToken, nonce: nonce)
            let loginResult = try await socialLoginUseCase.loginWithApple(credential)
            YGLogger.log("Apple 로그인 완료: \(loginResult)")
            handle(loginResult)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // 사용자가 로그인 시트를 닫음 — 정상 흐름
        } catch {
            YGLogger.error("Apple 로그인 실패: \(error)")
        }
    }

    private func handle(_ result: SocialLoginResult) {
        switch result {
        case .signedIn, .signupRequired:
            // ponytail: 기존회원(.signedIn)은 메인으로 보내고 registrationToken 은 약관 화면에 넘겨야 함 —
            //           Routing 페이로드 설계(공용 모듈이라 팀 컨펌 필요) 후 분기. 지금은 둘 다 약관 화면으로.
            eventContinuation.yield(.authenticated)
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

    /// 뷰가 소비하는 일회성 이벤트.
    enum Event: Sendable {
        /// 로그인 성공 — 약관 동의 화면으로 이동.
        case authenticated
    }
}
