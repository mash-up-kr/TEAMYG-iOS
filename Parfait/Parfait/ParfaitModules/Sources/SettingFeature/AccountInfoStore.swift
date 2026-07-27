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

    /// 일회성 이벤트 채널(네비게이션 등). state 에 넣으면 재진입 시 재발화되므로 분리. (mvi.md)
    let events: AsyncStream<Event>
    @ObservationIgnored private let eventContinuation: AsyncStream<Event>.Continuation

    /// 닉네임은 아직 Domain(UseCase) 이 없어 초기 State 로 주입받는다.
    /// 사용자 정보 UseCase 가 생기면 로드 Intent 로 교체.
    public init(state: State = State()) {
        self.state = state
        (events, eventContinuation) = AsyncStream.makeStream()
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .nicknameChanged(let nickname):
            state.nickname = nickname
        case .confirmTapped:
            guard state.nicknameErrorMessage == nil else { return }
            // TODO: 닉네임 변경 UseCase 연결 — 서버 성공 시에만 이벤트 발행
            eventContinuation.yield(.nicknameSaved)
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
        case confirmTapped
    }

    /// 뷰가 소비하는 일회성 이벤트.
    enum Event: Sendable {
        /// 닉네임 변경 완료 — 이전 화면으로 복귀.
        case nicknameSaved
    }
}
