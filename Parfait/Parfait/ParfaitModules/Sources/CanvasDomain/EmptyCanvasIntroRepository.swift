//
//  EmptyCanvasIntroRepository.swift
//  CanvasDomain
//
//  Created by 박서연 on 11/23/26.
//

public protocol EmptyCanvasIntroRepository: Sendable {
    func markPlayedIfNeeded(groupID: Int, on date: ParfaitDate) async -> Bool
}
