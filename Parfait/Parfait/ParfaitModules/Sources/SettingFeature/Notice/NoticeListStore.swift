//
//  NoticeListStore.swift
//  SettingFeature
//
//  Created by 박서연 on 11/10/26.
//

import Common
import NoticeDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class NoticeListStore: MVIStore {
    public private(set) var state = State()

    var events: AsyncStream<Event> {
        AsyncStream { continuation in
            eventContinuation?.finish()
            eventContinuation = continuation
        }
    }
    @ObservationIgnored private var eventContinuation: AsyncStream<Event>.Continuation?

    private let noticeUseCase: any NoticeUseCase
    private let logAnalyticsEvent: AnalyticsEventLogger
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    public init(
        noticeUseCase: any NoticeUseCase,
        logAnalyticsEvent: @escaping AnalyticsEventLogger
    ) {
        self.noticeUseCase = noticeUseCase
        self.logAnalyticsEvent = logAnalyticsEvent
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            logAnalyticsEvent(.screenView(.appNotice))
            beginLoad()
        case .noticeTapped(let notice):
            logAnalyticsEvent(.appNoticeItemTapped(noticeID: notice.id, isNew: notice.isNew))
            markAsRead(notice)
        }
    }

    private func beginLoad() {
        guard loadTask == nil, state.phase != .loaded else { return }
        state.phase = .loading
        loadTask = Task {
            defer { loadTask = nil }
            do {
                state.notices = try await noticeUseCase.fetchNotices()
                state.phase = .loaded
            } catch {
                YGLogger.error("공지 목록 조회 실패: \(error)")
                state.phase = .failed
                eventContinuation?.yield(.loadFailed)
            }
        }
    }

    private func markAsRead(_ notice: Notice) {
        guard notice.isNew,
              let index = state.notices.firstIndex(where: { $0.id == notice.id })
        else { return }
        state.notices[index].isNew = false
        Task { await noticeUseCase.markAsRead(noticeID: notice.id) }
    }

    public struct State: Equatable {
        public var notices: [Notice] = []
        public var phase: Phase = .idle
    }

    public enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    public enum Intent {
        case screenAppeared
        case noticeTapped(Notice)
    }

    enum Event {
        case loadFailed
    }
}
