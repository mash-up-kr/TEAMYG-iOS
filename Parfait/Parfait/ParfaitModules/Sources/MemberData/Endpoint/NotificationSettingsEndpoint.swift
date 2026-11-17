//
//  NotificationSettingsEndpoint.swift
//  MemberData
//
//  Created by 김남수 on 11/16/26.
//

import Core

/// 알림 설정 조회 (`GET /api/v1/notifications/settings`).
struct FetchNotificationSettingsEndpoint: Endpoint {
    var path: String { "/api/v1/notifications/settings" }
    var method: HTTPMethod { .get }
}

/// 알림 설정 변경 (`PATCH /api/v1/notifications/settings`) — 보낸 항목만 바뀐다.
struct UpdateNotificationSettingsEndpoint: Endpoint {
    let dailyReminderEnabled: Bool?
    let activityDigestEnabled: Bool?

    var path: String { "/api/v1/notifications/settings" }
    var method: HTTPMethod { .patch }
    var task: RequestTask {
        .body(
            Body(
                dailyReminderEnabled: dailyReminderEnabled,
                activityDigestEnabled: activityDigestEnabled
            )
        )
    }

    /// nil 필드는 합성 Encodable 이 키째 생략한다 → 서버가 그 항목을 유지.
    struct Body: Encodable, Sendable {
        let dailyReminderEnabled: Bool?
        let activityDigestEnabled: Bool?
    }
}
