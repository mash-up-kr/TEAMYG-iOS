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
/// 오프셋 없는 값이 하나 섞이면 `.iso8601` 은 디코딩 자체를 실패시켜 응답 전체가 날아가는데,
/// 문자열로 받으면 못 읽는 값 하나가 그 항목의 시각만 nil 로 만들고 나머지는 그대로 그려진다.
///
/// 원래 `GroupData` 에 있었다. 날짜를 내려주는 API 가 그룹 목록 말고도 있어서
/// (`TodayParfaitImageResponse.createdAt`) 옮겨 왔다 — 캔버스도 같은 파서를 쓴다.
///
/// ponytail: 개발 서버가 실제로 내려주는 값은 **오프셋 없는** `2026-08-20T23:00:59` 형태다 (#79 확인).
///           지금 규칙대로면 그룹 목록의 활동 시각이 전부 nil 이라 칩에 시각이 안 뜬다.
///           백엔드에 오프셋(`+09:00`) 포함을 요청해 둔 상태이고, 붙으면 그대로 읽힌다.
public enum ServerDate {
    /// 오프셋(`Z`·`+09:00`)이 붙은 ISO8601 만 읽는다. 소수점 초는 있어도 되고 없어도 된다.
    ///
    /// 오프셋이 없으면 읽지 않고 nil 을 준다 — 어느 시간대인지 알 수 없어서다.
    /// 임의로 정해 버리면 방금 올린 토핑이 "9시간 전" 으로 보이는 식의 거짓 문구가 된다.
    /// 없는 편이 틀린 것보다 낫다.
    public static func date(from text: String) -> Date? {
        // `ISO8601DateFormatter` 는 Sendable 이 아니라 static 으로 공유할 수 없다.
        // 값 타입인 `Date.ISO8601FormatStyle` 을 쓰면 매번 만들지 않고 재사용할 수 있다.
        if let date = try? withFractionalSeconds.parse(text) {
            return date
        }
        return try? withoutFractionalSeconds.parse(text)
    }

    // 소수점 초 유무에 따라 스타일이 갈린다 — 하나로 둘 다 파싱되지 않는다.
    private static let withFractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let withoutFractionalSeconds = Date.ISO8601FormatStyle()
}
