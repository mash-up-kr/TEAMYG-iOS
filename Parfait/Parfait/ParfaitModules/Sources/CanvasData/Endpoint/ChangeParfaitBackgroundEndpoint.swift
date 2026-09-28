//
//  ChangeParfaitBackgroundEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import CanvasDomain
import Core

/// 캔버스 배경 변경 (`PATCH /api/v1/groups/{groupId}/parfaits/{parfaitId}/background`).
struct ChangeParfaitBackgroundEndpoint: Endpoint {
    let groupID: Int
    let parfaitID: Int
    let background: ParfaitBackgroundChange

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/background" }
    var method: HTTPMethod { .patch }
    var task: RequestTask { .body(Body(background)) }

    struct Body: Encodable, Sendable {
        let type: String
        let value: String?
        let imageId: Int?

        init(_ background: ParfaitBackgroundChange) {
            switch background {
            case .color(let hex):
                type = "COLOR"
                value = hex
                imageId = nil
            case .image(let imageID):
                type = "IMAGE"
                value = nil
                imageId = imageID
            }
        }
    }
}
