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
        case .accountInfoTapped:
            break // TODO: 계정 정보 화면 라우팅 (AppRoute 케이스 필요 — Routing 수정은 팀 컨펌)
        case .termsOfServiceTapped:
            break // TODO: 서비스 이용약관 화면 라우팅
        case .privacyPolicyTapped:
            break // TODO: 개인정보 처리 방침 화면 라우팅
        }
    }

    public struct State: Equatable {
        public var nickname: String
        public var loginProvider: String
        /// 표시용 문자열 그대로 (예: "1.0v")
        public var appVersion: String

        public init(
            nickname: String = "",
            loginProvider: String = "",
            appVersion: String = ""
        ) {
            self.nickname = nickname
            self.loginProvider = loginProvider
            self.appVersion = appVersion
        }
    }

    public enum Intent {
        case accountInfoTapped
        case termsOfServiceTapped
        case privacyPolicyTapped
    }
}
