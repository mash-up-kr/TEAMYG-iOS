//
//  UpdateTextEndpoint.swift
//  CanvasData
//
//  Created by 김남수 on 10/26/26.
//

import CanvasDomain
import Core

/// 텍스트 편집 (`PATCH /api/v1/groups/{groupId}/parfaits/{parfaitId}/texts/{parfaitTextId}`).
/// `nil` 필드는 인코딩에서 빠져 서버가 기존 값을 유지한다.
struct UpdateTextEndpoint: Endpoint {
    let groupID: Int
    let parfaitID: Int
    let textID: Int
    let update: TextUpdate

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/texts/\(textID)" }
    var method: HTTPMethod { .patch }
    var task: RequestTask { .body(Body(update)) }

    struct Body: Encodable, Sendable {
        let positionX: Double?
        let positionY: Double?
        let positionZ: Int?
        let scale: Double?
        let rotation: Double?
        let color: String?
        let isFill: Bool?
        let isStroke: Bool?
        let textAlign: String?

        init(_ update: TextUpdate) {
            positionX = update.placement.positionX
            positionY = update.placement.positionY
            positionZ = update.placement.positionZ
            scale = update.placement.scale
            rotation = update.placement.rotation
            color = update.colorHex
            isFill = update.isFill
            isStroke = update.isStroke
            textAlign = update.alignment?.serverValue
        }
    }
}
