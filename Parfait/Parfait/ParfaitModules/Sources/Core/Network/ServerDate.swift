//
//  ServerDate.swift
//  Core
//
//  Created by 신상우 on 8/23/26.
//

import Foundation

/// 서버 날짜 문자열 → `Date`.
///
/// 공용 디코더(`NetworkClientImpl` 의 `.iso8601`)에 맡기지 않고 DTO 가 문자열로 받아 여기서 옮긴다.
/// 못 읽는 값이 하나 섞여도 그 항목의 시각만 nil 이 되고 나머지는 그대로 그려진다 —
/// 디코더에 맡기면 응답 전체가 날아간다.
///
/// 원래 `GroupData` 에 있었다. 날짜를 내려주는 API 가 그룹 목록 말고도 있어서
/// (`TodayParfaitImageResponse.createdAt`) 옮겨 왔다 — 캔버스도 같은 파서를 쓴다.
public enum ServerDate {
    /// ISO 8601 을 읽는다. 오프셋(`Z`·`+09:00`)이 붙어 있으면 그대로 따르고,
    /// 없으면 ISO 8601 의 local time 규정대로 **기기 시간대**로 읽는다.
    ///
    /// 오프셋 없는 값은 시점(instant)이 아니라 벽시계 시각이라, 기기가 서버와 다른 시간대에
    /// 있으면 어긋난다. 국내 유저는 서버(서울)와 같아 맞아떨어진다.
    ///
    /// ponytail: 개발 서버가 오프셋 없는 `2026-09-07T00:09:49` 를 내려준다 (#79).
    ///           Spring 의 `LocalDateTime` 직렬화 형태다. `Instant`·`OffsetDateTime` 으로
    ///           바꿔달라고 요청해 둔 상태고, 붙으면 아래 오프셋 경로가 먼저 읽어 폴백은 안 탄다.
    public static func date(from text: String) -> Date? {
        // 소수점 초 유무에 따라 스타일이 갈린다 — 하나로 둘 다 파싱되지 않는다.
        if let date = try? withFractionalSeconds.parse(text) {
            return date
        }
        if let date = try? withoutFractionalSeconds.parse(text) {
            return date
        }
        if let date = try? localTime(includingFractionalSeconds: true).parse(text) {
            return date
        }
        return try? localTime(includingFractionalSeconds: false).parse(text)
    }

    // `ISO8601DateFormatter` 는 Sendable 이 아니라 static 으로 공유할 수 없다.
    // 값 타입인 `Date.ISO8601FormatStyle` 을 쓰면 매번 만들지 않고 재사용할 수 있다.
    private static let withFractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let withoutFractionalSeconds = Date.ISO8601FormatStyle()

    /// 오프셋 없는 값을 읽는 스타일. 기기 시간대는 언제든 바뀔 수 있어 호출할 때마다 만든다.
    private static func localTime(includingFractionalSeconds: Bool) -> Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: .current)
            .year().month().day()
            .dateSeparator(.dash)
            .dateTimeSeparator(.standard)
            .time(includingFractionalSeconds: includingFractionalSeconds)
            .timeSeparator(.colon)
    }
}
