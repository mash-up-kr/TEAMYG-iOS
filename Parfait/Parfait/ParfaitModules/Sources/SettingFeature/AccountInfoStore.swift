//
//  AccountInfoStore.swift
//  SettingFeature
//
//  Created by 김남수 on 7/22/26.
//

import Common
import MemberDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class AccountInfoStore: MVIStore {
    public private(set) var state: State

    /// 일회성 이벤트 채널(네비게이션 등). state 에 넣으면 재진입 시 재발화되므로 분리. (mvi.md)
    /// 접근할 때마다 새 스트림을 발급한다 — 화면 전환 중 뷰의 `.task` 가 취소·재시작되면
    /// 취소가 기존 스트림을 영구 종료시켜 이후 yield 가 유실되기 때문 (#95). 단일 구독자 전제.
    var events: AsyncStream<Event> {
        AsyncStream { continuation in
            eventContinuation?.finish()
            eventContinuation = continuation
        }
    }
    @ObservationIgnored private var eventContinuation: AsyncStream<Event>.Continuation?

    private let memberUseCase: any MemberUseCase
    /// 진행 중 저장 작업 핸들 — 중복 요청 방지 (mvi.md)
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    public init(state: State = State(), memberUseCase: any MemberUseCase) {
        self.state = state
        self.memberUseCase = memberUseCase
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .nicknameChanged(let nickname):
            state.nickname = nickname
        case .confirmTapped:
            guard state.nicknameErrorMessage == nil, saveTask == nil else { return }
            saveTask = Task {
                defer { saveTask = nil }
                do {
                    let savedNickname = try await memberUseCase.changeNickname(state.nickname)
                    state.nickname = savedNickname
                    eventContinuation?.yield(.nicknameSaved)
                } catch {
                    // 에러 UI 정책 미정 — 로그만 남긴다 (docs/server-connection.md)
                    print("닉네임 변경 실패: \(error)")
                }
            }
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
