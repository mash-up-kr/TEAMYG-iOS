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
