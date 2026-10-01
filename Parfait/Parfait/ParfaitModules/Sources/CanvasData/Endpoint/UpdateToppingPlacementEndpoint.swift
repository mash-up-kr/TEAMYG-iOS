//
//  UpdateToppingPlacementEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import CanvasDomain
import Core

/// 토핑 배치 수정 (`PATCH /api/v1/groups/{groupId}/parfaits/{parfaitId}/images/{parfaitImageId}`).
struct UpdateToppingPlacementEndpoint: Endpoint {
    let groupID: Int
    let parfaitID: Int
    let toppingID: Int
    let update: ToppingPlacementUpdate

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/images/\(toppingID)" }
    var method: HTTPMethod { .patch }
    var task: RequestTask { .body(Body(update)) }

    struct Body: Encodable, Sendable {
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
}
