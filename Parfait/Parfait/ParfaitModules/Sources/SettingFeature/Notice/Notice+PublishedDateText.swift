//
//  Notice+PublishedDateText.swift
//  SettingFeature
//
//  Created by 박서연 on 11/10/26.
//

import Foundation
import NoticeDomain

extension Notice {
    var publishedDateText: String {
        guard let publishedDate else { return "" }
        return publishedDate.formatted(
            .verbatim(
                "\(year: .defaultDigits).\(month: .twoDigits).\(day: .twoDigits)",
                timeZone: .current,
                calendar: .current
            )
        )
    }
}
