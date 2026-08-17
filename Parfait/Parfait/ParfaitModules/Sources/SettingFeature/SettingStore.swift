//
//  SettingStore.swift
//  SettingFeature
//
//  Created by 김남수 on 7/21/26.
//

import AuthDomain
import MemberDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class SettingStore: MVIStore {
    public private(set) var state: State

    private let memberUseCase: any MemberUseCase
    private let authUseCase: any AuthUseCase
    /// 진행 중 작업 핸들 — 재진입 시 중복 실행 방지 (mvi.md)
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var actionTask: Task<Void, Never>?

    public init(
        memberUseCase: any MemberUseCase,
        authUseCase: any AuthUseCase,
        state: State = State()
    ) {
        self.memberUseCase = memberUseCase
        self.authUseCase = authUseCase
        self.state = state
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .appeared:
            // 계정 정보 화면에서 닉네임을 바꾸고 돌아온 경우도 있어 진입할 때마다 새로 조회한다.
            guard loadTask == nil else { return }
            loadTask = Task {
                defer { loadTask = nil }
                do {
                    let account = try await memberUseCase.fetchMyAccount()
                    state.nickname = account.nickname
                    state.loginProvider = account.provider
                } catch {
                    // 에러 UI 정책 미정 — 로그만 남긴다 (docs/server-connection.md)
                    print("내 계정 조회 실패: \(error)")
                }
            }
        case .logoutTapped:
            guard actionTask == nil else { return }
            actionTask = Task {
                defer { actionTask = nil }
                do {
                    // 성공 시 세션 종료 이벤트가 발행돼 App 루트가 로그인 화면으로 되돌린다.
                    try await authUseCase.logout()
                } catch {
                    print("로그아웃 실패: \(error)")
                }
            }
        case .withdrawTapped:
            state.isWithdrawPopupPresented = true
        case .withdrawPopupVisibilityChanged(let isPresented):
            state.isWithdrawPopupPresented = isPresented
        case .withdrawConfirmed:
            guard actionTask == nil else { return }
            actionTask = Task {
                defer { actionTask = nil }
                do {
                    // 성공 시 세션 종료 이벤트가 발행돼 App 루트가 로그인 화면으로 되돌린다.
                    try await memberUseCase.withdraw()
                } catch {
                    print("회원 탈퇴 실패: \(error)")
                }
            }
        }
    }

    public struct State: Equatable {
        public var nickname: String
        public var loginProvider: String
        /// 표시용 문자열 그대로 (예: "1.0v")
        public var appVersion: String
        public var isWithdrawPopupPresented: Bool

        public init(
            nickname: String = "",
            loginProvider: String = "",
            appVersion: String = "",
            isWithdrawPopupPresented: Bool = false
        ) {
            self.nickname = nickname
            self.loginProvider = loginProvider
            self.appVersion = appVersion
            self.isWithdrawPopupPresented = isWithdrawPopupPresented
        }
    }

    public enum Intent {
        /// 화면 진입 — 내 계정 정보를 조회한다.
        case appeared
        case logoutTapped
        case withdrawTapped
        case withdrawPopupVisibilityChanged(Bool)
        case withdrawConfirmed
    }
}
