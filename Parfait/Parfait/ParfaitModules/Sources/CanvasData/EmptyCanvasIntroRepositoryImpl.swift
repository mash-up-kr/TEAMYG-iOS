//
//  EmptyCanvasIntroRepositoryImpl.swift
//  CanvasData
//
//  Created by 박서연 on 11/23/26.
//

import CanvasDomain
import Foundation

public actor EmptyCanvasIntroRepositoryImpl: EmptyCanvasIntroRepository {
    public init() {}

    public func markPlayedIfNeeded(groupID: Int, on date: ParfaitDate) -> Bool {
        let playedDateKey = "canvas.emptyIntroPlayedDate.\(groupID)"
        let dateText = "\(date.year)-\(date.month)-\(date.day)"
        guard UserDefaults.standard.string(forKey: playedDateKey) != dateText else { return false }
        UserDefaults.standard.set(dateText, forKey: playedDateKey)
        return true
    }
}
