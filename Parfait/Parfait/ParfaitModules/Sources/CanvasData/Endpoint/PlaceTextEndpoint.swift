//
//  PlaceTextEndpoint.swift
//  CanvasData
//
//  Created by 김남수 on 10/26/26.
//

import CanvasDomain
import Core

/// 캔버스에 텍스트 배치 (`POST /api/v1/groups/{groupId}/parfaits/{parfaitId}/texts`).
struct PlaceTextEndpoint: Endpoint {
    let groupID: Int
    let parfaitID: Int
    let draft: TextDraft

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/texts" }
    var method: HTTPMethod { .post }
    var task: RequestTask { .body(Body(draft)) }

    struct Body: Encodable, Sendable {
        let text: String
        let positionX: Double
        let positionY: Double
        let positionZ: Int
        let scale: Double
        let rotation: Double
        let color: String
        let fontSize: Double
        let isFill: Bool
        let isStroke: Bool
        let textAlign: String

        init(_ draft: TextDraft) {
            text = draft.text
            positionX = draft.placement.positionX
            positionY = draft.placement.positionY
            positionZ = draft.placement.positionZ
            scale = draft.placement.scale
            rotation = draft.placement.rotation
            color = draft.colorHex
            fontSize = PlacedText.baseFontSize
            isFill = draft.isFill
            isStroke = draft.isStroke
            textAlign = draft.alignment.serverValue
        }
    }
}
