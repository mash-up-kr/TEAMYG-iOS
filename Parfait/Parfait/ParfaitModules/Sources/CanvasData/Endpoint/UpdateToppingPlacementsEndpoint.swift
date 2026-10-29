//
//  UpdateToppingPlacementsEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 10/9/26.
//

import CanvasDomain
import Core

struct UpdateToppingPlacementsEndpoint: Endpoint {
    let groupID: Int
    let parfaitID: Int
    let updates: [Int: ToppingPlacementUpdate]
    let textUpdates: [Int: ToppingPlacementUpdate]

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/images" }
    var method: HTTPMethod { .patch }
    var task: RequestTask { .body(Body(updates: updates, textUpdates: textUpdates)) }

    /// `items`·`textItems` 둘 다 서버 필수 필드 — 바뀐 게 없으면 빈 배열로 보낸다.
    struct Body: Encodable, Sendable {
        let items: [Item]
        let textItems: [TextItem]

        init(updates: [Int: ToppingPlacementUpdate], textUpdates: [Int: ToppingPlacementUpdate]) {
            items = updates
                .sorted { $0.key < $1.key }
                .map { Item(toppingID: $0.key, update: $0.value) }
            textItems = textUpdates
                .sorted { $0.key < $1.key }
                .map { TextItem(textID: $0.key, update: $0.value) }
        }
    }

    struct Item: Encodable, Sendable {
        let parfaitImageId: Int
        let positionX: Double?
        let positionY: Double?
        let positionZ: Int?
        let scale: Double?
        let rotation: Double?

        init(toppingID: Int, update: ToppingPlacementUpdate) {
            parfaitImageId = toppingID
            positionX = update.positionX
            positionY = update.positionY
            positionZ = update.positionZ
            scale = update.scale
            rotation = update.rotation
        }
    }

    struct TextItem: Encodable, Sendable {
        let parfaitTextId: Int
        let positionX: Double?
        let positionY: Double?
        let positionZ: Int?
        let scale: Double?
        let rotation: Double?

        init(textID: Int, update: ToppingPlacementUpdate) {
            parfaitTextId = textID
            positionX = update.positionX
            positionY = update.positionY
            positionZ = update.positionZ
            scale = update.scale
            rotation = update.rotation
        }
    }
}
