//
//  RelativeTimeText.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import Foundation

/// Grouptag-Chip 에 들어가는 상대시간 문구. 디자인 표기는 조사 없이 붙여쓴다("3분전").
enum RelativeTimeText {
    static func string(from date: Date, now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        guard elapsed >= 60 else { return "방금" }

        let minutes = Int(elapsed / 60)
        if minutes < 60 { return "\(minutes)분전" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours)시간전" }

        let days = hours / 24
        if days < 7 { return "\(days)일전" }

        // ponytail: 일주일이 넘는 경우의 표기는 디자인 미정 — 확정되면 교체.
        return date.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day())
    }
}
