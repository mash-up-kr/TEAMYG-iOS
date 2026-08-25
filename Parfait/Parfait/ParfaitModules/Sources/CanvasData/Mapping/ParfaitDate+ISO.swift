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
    /// 서버의 `date-time` 은 타임존이 없다(`2026-08-23T14:30:00`). 기기 현지 시각으로 읽는다 —
    /// 캔버스의 하루 경계도 기기 현지 시각 기준이라 같은 기준을 쓴다.
    static func parse(_ text: String?) -> Date? {
        guard let text else { return nil }
        return formatter.date(from: text)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
