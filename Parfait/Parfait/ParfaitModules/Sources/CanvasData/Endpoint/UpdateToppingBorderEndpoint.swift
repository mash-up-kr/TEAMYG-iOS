//
//  UpdateToppingBorderEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import CanvasDomain
import Core

/// 토핑 테두리 수정 (`PATCH /api/v1/groups/{groupId}/parfaits/{parfaitId}/images/{parfaitImageId}/border`).
struct UpdateToppingBorderEndpoint: Endpoint {
    let groupID: Int
    let parfaitID: Int
    let toppingID: Int
    let border: ToppingBorderStyle

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/images/\(toppingID)/border" }
    var method: HTTPMethod { .patch }
    var task: RequestTask { .body(Body(border)) }

    struct Body: Encodable, Sendable {
        let borderType: String
        let borderColor: String?
        let borderWidth: Double?

        init(_ border: ToppingBorderStyle) {
            let borderFields = border.requestFields
            borderType = borderFields.type
            borderColor = borderFields.color
            borderWidth = borderFields.width
        }
    }
}
