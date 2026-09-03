//
//  RelativeTimeText.swift
//  Common
//
//  Created by 신상우 on 8/1/26.
//

import Foundation

/// 지난 시각을 한국어 문구로 옮긴다. Grouptag-Chip 과 캔버스 Spotlight Toast 가 함께 쓴다.
///
/// 정책표: `방금 전` / `N분 전` / `N시간 전` / `N일 전` / `오래 전`(7일 이상).
public enum RelativeTimeText {
    /// 이 기간을 넘기면 경과 시간을 세지 않고 "오래 전" 으로 뭉갠다.
    private static let longAgoThresholdInDays = 7

    public static func string(from date: Date, now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        guard elapsed >= 60 else { return "방금 전" }

        let minutes = Int(elapsed / 60)
        if minutes < 60 { return "\(minutes)분 전" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours)시간 전" }

        let days = hours / 24
        if days < Self.longAgoThresholdInDays { return "\(days)일 전" }

        return "오래 전"
    }
}
