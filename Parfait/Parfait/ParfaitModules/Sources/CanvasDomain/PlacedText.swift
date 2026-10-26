//
//  PlacedText.swift
//  CanvasDomain
//
//  Created by 김남수 on 10/26/26.
//

import Foundation

/// 캔버스에 놓인 텍스트. 위치·배율·회전은 이미지 토핑과 같은 기준이고 `positionZ` 도 같은 축을 쓴다.
/// 서버 `fontSize` 는 쓰지 않는다 — 글자 크기는 기본 크기 × `scale` 로만 정한다.
/// 내용은 한 번 쌓으면 고칠 수 없다 (제품 정책).
public struct PlacedText: Identifiable, Equatable, Sendable {
    public let id: Int
    /// 받은 그대로 그린다. 줄바꿈은 작성자가 박아 보낸 개행만 따른다.
    public let text: String
    public let positionX: Double
    public let positionY: Double
    public let positionZ: Int
    public let scale: Double
    public let rotation: Double
    /// 글자색 hex. 형식이 깨졌으면 `nil` — 그리는 쪽이 기본색을 쓴다.
    public let colorHex: String?
    public let isFill: Bool
    public let isStroke: Bool
    public let placedBy: ParfaitMember
    public let ownerType: ToppingOwnerType
    public let createdAt: Date?

    public init(
        id: Int,
        text: String,
        positionX: Double,
        positionY: Double,
        positionZ: Int,
        scale: Double,
        rotation: Double,
        colorHex: String?,
        isFill: Bool,
        isStroke: Bool,
        placedBy: ParfaitMember,
        ownerType: ToppingOwnerType,
        createdAt: Date?
    ) {
        self.id = id
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.scale = scale
        self.rotation = rotation
        self.colorHex = colorHex
        self.isFill = isFill
        self.isStroke = isStroke
        self.placedBy = placedBy
        self.ownerType = ownerType
        self.createdAt = createdAt
    }
}

/// 캔버스에 새로 쌓을 텍스트.
public struct TextDraft: Equatable, Sendable {
    /// 줄바꿈을 개행으로 박은 내용 — 보는 쪽은 다시 줄바꿈하지 않는다.
    public let text: String
    /// `scale` 은 기본 글자 크기(`PlacedText.baseFontSize`) 대비 배율 — 자동 축소분과 핀치 배율을 합친 값.
    public let placement: ToppingPlacementValues
    public let colorHex: String
    public let isFill: Bool
    public let isStroke: Bool

    public init(text: String, placement: ToppingPlacementValues, colorHex: String, isFill: Bool, isStroke: Bool) {
        self.text = text
        self.placement = placement
        self.colorHex = colorHex
        self.isFill = isFill
        self.isStroke = isStroke
    }
}

/// 텍스트 편집 요청. 값이 있는 필드만 서버로 보낸다. 내용은 고칠 수 없어 필드가 없다.
public struct TextUpdate: Equatable, Sendable {
    public var placement: ToppingPlacementUpdate
    public var colorHex: String?
    public var isFill: Bool?
    public var isStroke: Bool?

    public init(
        placement: ToppingPlacementUpdate = ToppingPlacementUpdate(),
        colorHex: String? = nil,
        isFill: Bool? = nil,
        isStroke: Bool? = nil
    ) {
        self.placement = placement
        self.colorHex = colorHex
        self.isFill = isFill
        self.isStroke = isStroke
    }

    public var isEmpty: Bool {
        self == TextUpdate()
    }
}

public extension PlacedText {
    /// 서버 `fontSize` 에 늘 이 값을 보낸다. 글자 크기는 이 값 × `scale` 로만 정한다.
    static let baseFontSize: Double = 24
}
