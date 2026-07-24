//
//  AccountInfoStore.swift
//  SettingFeature
//
//  Created by 김남수 on 7/22/26.
//

import Common
import SwiftUI
import UIComponent

@Observable @MainActor
public final class AccountInfoStore: MVIStore {
    public private(set) var state: State

    /// 닉네임은 아직 Domain(UseCase) 이 없어 초기 State 로 주입받는다.
    /// 사용자 정보 UseCase 가 생기면 로드 Intent 로 교체.
    public init(state: State = State()) {
        self.state = state
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .nicknameChanged(let nickname):
            state.nickname = nickname
        case .logoutTapped:
            break // TODO: 로그아웃 UseCase 연결
        case .withdrawTapped:
            break // TODO: 서비스 탈퇴 UseCase 연결
        }
    }

    public struct State: Equatable {
        public var nickname: String

        /// 닉네임 정책 위반 안내 문구. 통과 시 nil.
        public var nicknameErrorMessage: String? {
            NicknameValidator.errorMessage(for: nickname)
        }

        public init(nickname: String = "") {
            self.nickname = nickname
        }
    }

    public enum Intent {
        case nicknameChanged(String)
        case logoutTapped
        case withdrawTapped
    }
}
