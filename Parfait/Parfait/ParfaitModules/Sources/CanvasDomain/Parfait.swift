//
//  Parfait.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

import Foundation

/// 하루치 캔버스.
public struct Parfait: Identifiable, Equatable, Sendable {
    public let id: Int
    public let date: ParfaitDate
    public let status: ParfaitStatus
    /// 가장 최근에 마감된 캔버스 날짜. SY-001-New 안내 노출 판단에 쓴다.
    public let lastClosedDate: ParfaitDate?
    public let members: [ParfaitMember]
    public let background: ParfaitBackground?
    public let toppings: [PlacedTopping]

    /// 배경도 토핑도 없는 캔버스. C-001-Empty 판정 기준이다.
    public var isEmpty: Bool {
        background == nil && toppings.isEmpty
    }

    public init(
        id: Int,
        date: ParfaitDate,
        status: ParfaitStatus,
        lastClosedDate: ParfaitDate?,
        members: [ParfaitMember],
        background: ParfaitBackground?,
        toppings: [PlacedTopping]
    ) {
        self.id = id
        self.date = date
        self.status = status
        self.lastClosedDate = lastClosedDate
        self.members = members
        self.background = background
        self.toppings = toppings.sorted { $0.positionZ < $1.positionZ }
    }
}

public enum ParfaitStatus: Sendable, Equatable {
    /// 오늘의 캔버스 — 토핑을 쌓을 수 있다.
    case active
    /// 마감된 캔버스 — 토핑이 하나 이상 있다.
    case closed
    /// 마감됐지만 토핑이 없던 캔버스.
    case empty
}

/// 캘린더·목록에 쓰는 캔버스 요약.
public struct ParfaitSummary: Identifiable, Equatable, Sendable {
    public let id: Int
    public let date: ParfaitDate
    public let thumbnailURL: URL?
    public let toppingCount: Int

    public init(id: Int, date: ParfaitDate, thumbnailURL: URL?, toppingCount: Int) {
        self.id = id
        self.date = date
        self.thumbnailURL = thumbnailURL
        self.toppingCount = toppingCount
    }
}
