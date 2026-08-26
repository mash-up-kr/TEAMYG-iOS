//
//  ParfaitDate+ISO.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import Foundation

extension ParfaitDate {
    var isoText: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    init?(isoText: String) {
        let parts = isoText.prefix(10).split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }
        self.init(year: year, month: month, day: day)
    }
}

enum ServerDateTime {
    /// 서버의 `date-time` 은 ISO 8601 UTC 형식이다 (`2026-08-25T17:51:56.260Z`).
    /// 이전 개발 서버의 타임존 없는 형식도 호환을 위해 기기 현지 시각으로 읽는다.
    static func parse(_ text: String?) -> Date? {
        guard let text else { return nil }
        return (try? iso8601FormatStyle.parse(text))
            ?? localDateTimeFormatter.date(from: text)
    }

    private static let iso8601FormatStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    private static let localDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
