//
//  NotificationSettings.swift
//  MemberDomain
//
//  Created by 김남수 on 11/16/26.
//

/// 알림 설정 엔티티 — 서버 `GET/PATCH /api/v1/notifications/settings` 응답에 대응.
public struct NotificationSettings: Equatable, Sendable {
    /// 오늘의 캔버스 알림
    public var isDailyReminderEnabled: Bool
    /// 알림 모아 받기
    public var isActivityDigestEnabled: Bool

    public init(isDailyReminderEnabled: Bool, isActivityDigestEnabled: Bool) {
        self.isDailyReminderEnabled = isDailyReminderEnabled
        self.isActivityDigestEnabled = isActivityDigestEnabled
    }
}
