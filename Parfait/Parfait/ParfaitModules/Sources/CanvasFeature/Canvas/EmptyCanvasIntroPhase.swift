//
//  EmptyCanvasIntroPhase.swift
//  CanvasFeature
//
//  Created by 박서연 on 11/23/26.
//

enum EmptyCanvasIntroPhase: Equatable, Sendable {
    case hidden
    case playing
    case completed

    var completingPlayback: Self {
        self == .playing ? .completed : self
    }

    var afterControlTap: Self {
        self == .playing ? .completed : .hidden
    }
}
