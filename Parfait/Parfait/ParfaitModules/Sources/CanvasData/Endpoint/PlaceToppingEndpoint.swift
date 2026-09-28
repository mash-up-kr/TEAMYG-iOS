//
//  PlaceToppingEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import CanvasDomain
import Core

/// 캔버스에 토핑 배치 (`POST /api/v1/groups/{groupId}/parfaits/{parfaitId}/images`).
struct PlaceToppingEndpoint: Endpoint {
    let groupID: Int
    let parfaitID: Int
    let imageID: Int
    let placement: ToppingPlacementValues
    let border: ToppingBorderStyle

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/images" }
    var method: HTTPMethod { .post }
    var task: RequestTask { .body(Body(imageID: imageID, placement: placement, border: border)) }

    struct Body: Encodable, Sendable {
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
            let borderFields = border.requestFields
            borderType = borderFields.type
            borderColor = borderFields.color
            borderWidth = borderFields.width
        }
    }
}
