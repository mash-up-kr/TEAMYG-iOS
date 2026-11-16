//
//  NotificationSettingStore.swift
//  SettingFeature
//
//  Created by 김남수 on 11/16/26.
//

import Common
import MemberDomain
import SwiftUI
import UIComponent
import UserNotifications

@Observable @MainActor
public final class NotificationSettingStore: MVIStore {
    public private(set) var state: State

    /// 일회성 이벤트 채널(토스트). 접근할 때마다 새 스트림을 발급한다 — 단일 구독자 전제 (AccountInfoStore 와 동일).
    var events: AsyncStream<Event> {
        AsyncStream { continuation in
            eventContinuation?.finish()
            eventContinuation = continuation
        }
    }
    @ObservationIgnored private var eventContinuation: AsyncStream<Event>.Continuation?

    private let memberUseCase: any MemberUseCase
    /// 기기(시스템) 알림 허용 여부 조회 — 프리뷰에서 바꿔 끼울 수 있도록 주입.
    private let isSystemNotificationAuthorized: @Sendable () async -> Bool
    private let logAnalyticsEvent: AnalyticsEventLogger
    /// 진행 중 작업 핸들 — 중복 요청 방지 (mvi.md)
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    public init(
        state: State = State(),
        memberUseCase: any MemberUseCase,
        logAnalyticsEvent: @escaping AnalyticsEventLogger,
        isSystemNotificationAuthorized: @escaping @Sendable () async -> Bool = {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            return [.authorized, .provisional, .ephemeral].contains(status)
        }
    ) {
        self.state = state
        self.memberUseCase = memberUseCase
        self.isSystemNotificationAuthorized = isSystemNotificationAuthorized
        self.logAnalyticsEvent = logAnalyticsEvent
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .appeared:
            beginLoad()
        case .sceneBecameActive:
            // 기기 설정에서 알림을 켜고 돌아온 경우를 반영한다.
            refreshSystemAuthorization()
        case .deviceSettingsTapped:
            logAnalyticsEvent(.appNotificationDeviceSettingsTapped)
        case .dailyReminderToggled(let isEnabled):
            save(.dailyReminder, isEnabled: isEnabled)
        case .activityDigestToggled(let isEnabled):
            save(.activityDigest, isEnabled: isEnabled)
        }
    }

    private func beginLoad() {
        guard loadTask == nil else { return }
        loadTask = Task {
            defer { loadTask = nil }
            state.isSystemNotificationAuthorized = await isSystemNotificationAuthorized()
            do {
                state.settings = try await memberUseCase.fetchNotificationSettings()
            } catch {
                // 조회 실패 UI 정책 미정 — 로그만 남기고 스위치는 비활성으로 둔다
                YGLogger.error("알림 설정 조회 실패: \(error)")
            }
        }
    }

    private func refreshSystemAuthorization() {
        Task {
            state.isSystemNotificationAuthorized = await isSystemNotificationAuthorized()
        }
    }

    /// 낙관적 갱신 — 스위치를 먼저 바꾸고, 바꾼 항목만 서버에 보낸다.
    /// 저장 중 들어온 탭은 무시한다 — 요청이 하나씩만 나가므로 순서·롤백 관리가 필요 없다.
    /// 실패하면 저장 전 값으로 되돌리고 에러 토스트.
    private func save(_ field: Field, isEnabled: Bool) {
        guard let previousSettings = state.settings, !state.isSaving else { return }
        state.settings?[keyPath: field.keyPath] = isEnabled
        state.isSaving = true
        Task {
            defer { state.isSaving = false }
            do {
                let saved = try await memberUseCase.updateNotificationSettings(
                    isDailyReminderEnabled: field == .dailyReminder ? isEnabled : nil,
                    isActivityDigestEnabled: field == .activityDigest ? isEnabled : nil
                )
                state.settings = saved
                logAnalyticsEvent(
                    .appNotificationSettingChanged(
                        type: field.analyticsType,
                        isEnabled: saved[keyPath: field.keyPath]
                    )
                )
            } catch {
                YGLogger.error("알림 설정 변경 실패: \(error)")
                state.settings = previousSettings
                eventContinuation?.yield(.saveFailed)
            }
        }
    }

    private enum Field {
        case dailyReminder
        case activityDigest

        var keyPath: WritableKeyPath<NotificationSettings, Bool> {
            switch self {
            case .dailyReminder: \.isDailyReminderEnabled
            case .activityDigest: \.isActivityDigestEnabled
            }
        }

        var analyticsType: AnalyticsEvent.NotificationSettingType {
            switch self {
            case .dailyReminder: .canvas
            case .activityDigest: .activity
            }
        }
    }

    public struct State: Equatable {
        /// 서버 알림 설정. 조회 전에는 nil — 스위치를 비활성으로 그린다.
        public var settings: NotificationSettings?
        /// 기기 설정에서 파르페 알림을 허용했는지. 꺼져 있으면 안내 카드를 띄우고 스위치를 비활성화한다.
        public var isSystemNotificationAuthorized: Bool
        /// 저장 요청 진행 중 — 이 동안 들어온 스위치 탭은 무시한다. 깜빡임 방지로 disabled 스타일은 걸지 않는다.
        public var isSaving = false

        /// 스위치 조작 가능 여부.
        public var isToggleEnabled: Bool {
            isSystemNotificationAuthorized && settings != nil
        }

        /// 서버 조회 전 표시값 — 기본값 캔버스 알림 on · 활동 알림 모아 받기 off. 실제 값은 서버 응답이 덮어쓴다.
        public var isDailyReminderEnabled: Bool { settings?.isDailyReminderEnabled ?? true }
        public var isActivityDigestEnabled: Bool { settings?.isActivityDigestEnabled ?? false }

        public init(settings: NotificationSettings? = nil, isSystemNotificationAuthorized: Bool = true) {
            self.settings = settings
            self.isSystemNotificationAuthorized = isSystemNotificationAuthorized
        }
    }

    public enum Intent {
        case appeared
        case sceneBecameActive
        /// 기기 알림 꺼짐 안내 카드의 설정으로 이동 — 이동 자체는 뷰가 openURL 로 처리한다.
        case deviceSettingsTapped
        case dailyReminderToggled(Bool)
        case activityDigestToggled(Bool)
    }

    /// 뷰가 소비하는 일회성 이벤트.
    enum Event: Sendable {
        /// 설정 저장 실패 — 에러 토스트.
        case saveFailed
    }
}
