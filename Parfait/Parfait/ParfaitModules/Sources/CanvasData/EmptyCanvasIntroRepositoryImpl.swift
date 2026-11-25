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

    public func hasPlayed(groupID: Int, on date: ParfaitDate) -> Bool {
        UserDefaults.standard.string(forKey: playedDateKey(groupID: groupID)) == date.isoText
    }

    public func markPlayed(groupID: Int, on date: ParfaitDate) {
        UserDefaults.standard.set(date.isoText, forKey: playedDateKey(groupID: groupID))
    }

    private func playedDateKey(groupID: Int) -> String {
        "canvas.emptyIntroPlayedDate.\(groupID)"
    }
}
