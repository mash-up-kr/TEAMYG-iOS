//
//  NotificationSettingsResponseDTO.swift
//  MemberData
//
//  Created by 김남수 on 11/16/26.
//

/// `GET/PATCH /api/v1/notifications/settings` 응답 스키마 대응.
struct NotificationSettingsResponseDTO: Decodable, Sendable {
    let dailyReminderEnabled: Bool
    let activityDigestEnabled: Bool
}
