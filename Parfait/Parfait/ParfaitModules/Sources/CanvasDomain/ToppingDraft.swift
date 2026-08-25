//
//  ToppingDraft.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 아직 서버에 올리지 않은 토핑. C-106 에서 확정한 배치 값을 담는다.
/// 좌표·크기는 이미 정규화된 값이며 서버는 그대로 저장한다 (`topping-api.md` §8).
public struct ToppingDraft: Equatable, Sendable {
    public let image: ImageUpload
    public let placement: ToppingPlacementValues
    public let border: ToppingBorderStyle

    public init(image: ImageUpload, placement: ToppingPlacementValues, border: ToppingBorderStyle) {
        self.image = image
        self.placement = placement
        self.border = border
    }
}

/// 토핑의 위치·크기·회전. 배치 확정과 편집이 같은 값을 쓴다.
public struct ToppingPlacementValues: Equatable, Sendable {
    public let positionX: Double
    public let positionY: Double
    public let positionZ: Int
    public let scale: Double
    public let rotation: Double

    public init(positionX: Double, positionY: Double, positionZ: Int, scale: Double, rotation: Double) {
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.scale = scale
        self.rotation = rotation
    }
}

/// 토핑 편집 요청. 값이 있는 필드만 서버로 보낸다.
public struct ToppingPlacementUpdate: Equatable, Sendable {
    public var positionX: Double?
    public var positionY: Double?
    public var positionZ: Int?
    public var scale: Double?
    public var rotation: Double?

    public init(
        positionX: Double? = nil,
        positionY: Double? = nil,
        positionZ: Int? = nil,
        scale: Double? = nil,
        rotation: Double? = nil
    ) {
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.scale = scale
        self.rotation = rotation
    }
}
