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
    /// 캔버스가 속한 그룹 이름. 과거 스키마 응답엔 없을 수 있다.
    public let groupName: String?
    public let date: ParfaitDate
    /// 가장 최근에 마감된 캔버스 날짜. SY-001-New 안내 노출 판단에 쓴다.
    public let lastClosedDate: ParfaitDate?
    public let members: [ParfaitMember]
    public let background: ParfaitBackground?
    public let toppings: [PlacedTopping]
    public let texts: [PlacedText]

    /// 배경도 토핑(이미지·텍스트)도 없는 캔버스. C-001-Empty 판정 기준이다.
    public var isEmpty: Bool {
        background == nil && toppings.isEmpty && texts.isEmpty
    }

    public init(
        id: Int,
        groupName: String?,
        date: ParfaitDate,
        lastClosedDate: ParfaitDate?,
        members: [ParfaitMember],
        background: ParfaitBackground?,
        toppings: [PlacedTopping],
        texts: [PlacedText] = []
    ) {
        self.id = id
        self.groupName = groupName
        self.date = date
        self.lastClosedDate = lastClosedDate
        self.members = members
        self.background = background
        self.toppings = toppings.sorted { $0.positionZ < $1.positionZ }
        self.texts = texts.sorted { $0.positionZ < $1.positionZ }
    }
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
