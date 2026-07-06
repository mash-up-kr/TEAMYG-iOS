//
//  LoginStore.swift
//  LoginFeature
//
//  Created by 김남수 on 7/3/26.
//

import AuthenticationServices
import Observation
import SwiftUI // AuthorizationController 는 AuthenticationServices+SwiftUI 크로스 임포트 타입
import UIComponent

@Observable @MainActor
final class LoginStore: MVIStore {
    private(set) var state = State()

    @ObservationIgnored private var appleLoginTask: Task<Void, Never>?

    func send(_ intent: Intent) {
        switch intent {
        case .pageChanged(let pageIndex):
            state.currentPageIndex = pageIndex
        case .kakaoLoginTapped:
            break // ponytail: UI만 — 로그인 연동 시 구현
        case .appleLoginTapped(let authorizationController):
            guard appleLoginTask == nil else { return }
            appleLoginTask = Task {
                await performAppleLogin(using: authorizationController)
                appleLoginTask = nil
            }
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

    struct State: Equatable {
        var currentPageIndex = 0
    }

    enum Intent {
        case pageChanged(Int)
        case kakaoLoginTapped
        case appleLoginTapped(AuthorizationController)
    }
}
