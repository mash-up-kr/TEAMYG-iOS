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

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/images" }
    var method: HTTPMethod { .patch }
    var task: RequestTask { .body(Body(updates)) }

    struct Body: Encodable, Sendable {
        let items: [Item]

        init(_ updates: [Int: ToppingPlacementUpdate]) {
            items = updates
                .sorted { $0.key < $1.key }
                .map { Item(toppingID: $0.key, update: $0.value) }
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
}
