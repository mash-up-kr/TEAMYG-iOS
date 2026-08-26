//
//  PlacedTopping.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

import Foundation

/// 캔버스에 배치된 토핑 하나. 좌표·크기는 정규화 값이다 (`topping-api.md` §8).
public struct PlacedTopping: Identifiable, Equatable, Sendable {
    public let id: Int
    public let imageID: Int
    public let imageURL: URL
    public let positionX: Double
    public let positionY: Double
    public let positionZ: Int
    public let scale: Double
    public let rotation: Double
    public let border: ToppingBorderStyle
    public let placedBy: ParfaitMember
    public let ownerType: ToppingOwnerType
    public let createdAt: Date?

    public init(
        id: Int,
        imageID: Int,
        imageURL: URL,
        positionX: Double,
        positionY: Double,
        positionZ: Int,
        scale: Double,
        rotation: Double,
        border: ToppingBorderStyle,
        placedBy: ParfaitMember,
        ownerType: ToppingOwnerType = .unknown,
        createdAt: Date?
    ) {
        self.id = id
        self.imageID = imageID
        self.imageURL = imageURL
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.scale = scale
        self.rotation = rotation
        self.border = border
        self.placedBy = placedBy
        self.ownerType = ownerType
        self.createdAt = createdAt
    }
}

/// 현재 로그인 사용자 기준 토핑 소유자. 서버의 `placedBy.ownerType` 값을 그대로 보존한다.
public enum ToppingOwnerType: Equatable, Sendable {
    case currentUser
    case other
    case unknown
}
