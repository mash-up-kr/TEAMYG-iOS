//
//  SettingStore.swift
//  SettingFeature
//
//  Created by 김남수 on 7/21/26.
//

import SwiftUI
import UIComponent

@Observable @MainActor
public final class SettingStore: MVIStore {
    public private(set) var state: State

    /// 프로필·버전은 아직 Domain(UseCase) 이 없어 초기 State 로 주입받는다.
    /// 사용자 정보 UseCase 가 생기면 로드 Intent 로 교체.
    public init(state: State = State()) {
        self.state = state
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .logoutTapped:
            break // TODO: 로그아웃 UseCase 연결
        case .withdrawTapped:
            state.isWithdrawPopupPresented = true
        case .withdrawPopupVisibilityChanged(let isPresented):
            state.isWithdrawPopupPresented = isPresented
        case .withdrawConfirmed:
            print("서비스 탈퇴 확인") // TODO: 서비스 탈퇴 UseCase 연결
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
        case logoutTapped
        case withdrawTapped
        case withdrawPopupVisibilityChanged(Bool)
        case withdrawConfirmed
    }
}
