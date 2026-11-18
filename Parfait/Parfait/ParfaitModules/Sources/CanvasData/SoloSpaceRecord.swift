//
//  SoloSpaceRecord.swift
//  CanvasData
//
//  Created by 김남수 on 11/18/26.
//

import CanvasDomain
import Foundation

// MARK: - 저장 형식

/// 한 계정의 혼자 공간 디렉터리.
struct SoloSpaceDirectory {
    let memberID: Int
    let directoryURL: URL

    var recordURL: URL { directoryURL.appending(path: "canvas.json") }
    var imagesURL: URL { directoryURL.appending(path: "Images", directoryHint: .isDirectory) }

    func imageURL(_ fileName: String) -> URL { imagesURL.appending(path: fileName) }
}

/// `canvas.json` 의 형식. 이미지는 파일명만 적는다 — 앱 컨테이너 경로는 업데이트마다 바뀔 수 있어 읽을 때 붙인다.
struct SoloSpaceRecord: Codable {
    var nextID = 1
    /// 업로드했지만 아직 배치·배경에 쓰이지 않은 이미지. 쓰이는 순간 빠진다.
    var uploads: [Int: String] = [:]
    var background: Background?
    var toppings: [Topping] = []
    var texts: [Text] = []

    mutating func issueID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    enum Background: Codable {
        case color(hex: String)
        case image(fileName: String)
    }

    struct Placement: Codable {
        var positionX: Double
        var positionY: Double
        var positionZ: Int
        var scale: Double
        var rotation: Double
    }

    struct Border: Codable {
        let colorHex: String
        let width: Double
    }

    struct Topping: Codable {
        let id: Int
        let fileName: String
        var placement: Placement
        /// `nil` 이면 테두리 없음.
        var border: Border?
        let createdAt: Date
    }

    enum Alignment: String, Codable {
        case left, center, right
    }

    struct Text: Codable {
        let id: Int
        let text: String
        var placement: Placement
        let colorHex: String
        let isFill: Bool
        let isStroke: Bool
        let alignment: Alignment
        let createdAt: Date
    }
}

extension SoloSpaceRecord.Background {
    func entity(in space: SoloSpaceDirectory) -> ParfaitBackground {
        switch self {
        case .color(let hex): .color(hex: hex)
        case .image(let fileName): .image(url: space.imageURL(fileName))
        }
    }
}

extension SoloSpaceRecord.Topping {
    func entity(in space: SoloSpaceDirectory) -> PlacedTopping {
        PlacedTopping(
            id: id,
            imageURL: space.imageURL(fileName),
            positionX: placement.positionX,
            positionY: placement.positionY,
            positionZ: placement.positionZ,
            scale: placement.scale,
            rotation: placement.rotation,
            border: border.map { .solid(colorHex: $0.colorHex, width: $0.width) } ?? ToppingBorderStyle.none,
            placedBy: SoloSpaceRepositoryImpl.owner(memberID: space.memberID),
            ownerType: .currentUser,
            createdAt: createdAt
        )
    }
}

extension SoloSpaceRecord.Text {
    func entity(owner: ParfaitMember) -> PlacedText {
        PlacedText(
            id: id,
            text: text,
            positionX: placement.positionX,
            positionY: placement.positionY,
            positionZ: placement.positionZ,
            scale: placement.scale,
            rotation: placement.rotation,
            colorHex: colorHex,
            isFill: isFill,
            isStroke: isStroke,
            alignment: alignment.entity,
            placedBy: owner,
            ownerType: .currentUser,
            createdAt: createdAt
        )
    }
}

extension SoloSpaceRecord.Placement {
    init(_ values: ToppingPlacementValues) {
        self.init(
            positionX: values.positionX,
            positionY: values.positionY,
            positionZ: values.positionZ,
            scale: values.scale,
            rotation: values.rotation
        )
    }

    mutating func apply(_ update: ToppingPlacementUpdate) {
        positionX = update.positionX ?? positionX
        positionY = update.positionY ?? positionY
        positionZ = update.positionZ ?? positionZ
        scale = update.scale ?? scale
        rotation = update.rotation ?? rotation
    }
}

extension SoloSpaceRecord.Border {
    init?(_ style: ToppingBorderStyle) {
        guard case .solid(let colorHex, let width) = style else { return nil }
        self.init(colorHex: colorHex, width: width)
    }
}

extension SoloSpaceRecord.Alignment {
    init(_ alignment: PlacedTextAlignment) {
        switch alignment {
        case .left: self = .left
        case .center: self = .center
        case .right: self = .right
        }
    }

    var entity: PlacedTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }
}
