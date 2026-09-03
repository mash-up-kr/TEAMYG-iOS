//
//  ToppingEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import Core

/// 캔버스에 놓인 토핑의 배치·편집·삭제 엔드포인트 묶음.
enum ToppingEndpoint: Endpoint {
    case place(
        groupID: Int,
        parfaitID: Int,
        imageID: Int,
        placement: ToppingPlacementValues,
        border: ToppingBorderStyle
    )
    case updatePlacement(groupID: Int, parfaitID: Int, toppingID: Int, update: ToppingPlacementUpdate)
    case updateBorder(groupID: Int, parfaitID: Int, toppingID: Int, border: ToppingBorderStyle)
    case delete(groupID: Int, parfaitID: Int, toppingID: Int)

    var path: String {
        switch self {
        case .place(let groupID, let parfaitID, _, _, _):
            Self.base(groupID: groupID, parfaitID: parfaitID)
        case .updatePlacement(let groupID, let parfaitID, let toppingID, _),
             .delete(let groupID, let parfaitID, let toppingID):
            "\(Self.base(groupID: groupID, parfaitID: parfaitID))/\(toppingID)"
        case .updateBorder(let groupID, let parfaitID, let toppingID, _):
            "\(Self.base(groupID: groupID, parfaitID: parfaitID))/\(toppingID)/border"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .place: .post
        case .updatePlacement, .updateBorder: .patch
        case .delete: .delete
        }
    }

    var task: RequestTask {
        switch self {
        case .place(_, _, let imageID, let placement, let border):
            .body(PlaceBody(imageID: imageID, placement: placement, border: border))
        case .updatePlacement(_, _, _, let update):
            .body(PlacementBody(update))
        case .updateBorder(_, _, _, let border):
            .body(BorderBody(border))
        case .delete:
            .plain
        }
    }

    private static func base(groupID: Int, parfaitID: Int) -> String {
        "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/images"
    }

    struct PlaceBody: Encodable, Sendable {
        let imageId: Int
        let positionX: Double
        let positionY: Double
        let positionZ: Int
        let scale: Double
        let rotation: Double
        let borderType: String
        let borderColor: String?
        let borderWidth: Double?

        init(imageID: Int, placement: ToppingPlacementValues, border: ToppingBorderStyle) {
            imageId = imageID
            positionX = placement.positionX
            positionY = placement.positionY
            positionZ = placement.positionZ
            scale = placement.scale
            rotation = placement.rotation
            let borderBody = BorderBody(border)
            borderType = borderBody.borderType
            borderColor = borderBody.borderColor
            borderWidth = borderBody.borderWidth
        }
    }

    /// 값이 없는 필드는 키째로 빠져야 한다 — 서버가 partial update 로 읽는다.
    struct PlacementBody: Encodable, Sendable {
        let positionX: Double?
        let positionY: Double?
        let positionZ: Int?
        let scale: Double?
        let rotation: Double?

        init(_ update: ToppingPlacementUpdate) {
            positionX = update.positionX
            positionY = update.positionY
            positionZ = update.positionZ
            scale = update.scale
            rotation = update.rotation
        }
    }

    struct BorderBody: Encodable, Sendable {
        let borderType: String
        let borderColor: String?
        let borderWidth: Double?

        init(_ border: ToppingBorderStyle) {
            switch border {
            case .none:
                borderType = "NONE"
                borderColor = nil
                borderWidth = nil
            case .solid(let colorHex, let width):
                borderType = "SOLID"
                borderColor = colorHex
                borderWidth = width
            }
        }
    }
}
