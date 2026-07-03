//
//  LoginStore.swift
//  LoginFeature
//
//  Created by 김남수 on 7/3/26.
//

import Observation
import UIComponent

@Observable @MainActor
final class LoginStore: MVIStore {
    private(set) var state = State()

    func send(_ intent: Intent) {
        switch intent {
        case .pageChanged(let pageIndex):
            state.currentPageIndex = pageIndex
        case .kakaoLoginTapped:
            break // ponytail: UI만 — 로그인 연동 시 구현
        case .appleLoginTapped:
            break // ponytail: UI만 — 로그인 연동 시 구현
        }
    }

    struct State: Equatable {
        var currentPageIndex = 0
    }

    enum Intent {
        case pageChanged(Int)
        case kakaoLoginTapped
        case appleLoginTapped
    }
}
