//
//  DeleteTextEndpoint.swift
//  CanvasData
//
//  Created by 김남수 on 10/26/26.
//

import Core

/// 텍스트 삭제 (`DELETE /api/v1/groups/{groupId}/parfaits/{parfaitId}/texts/{parfaitTextId}`).
struct DeleteTextEndpoint: Endpoint {
    let groupID: Int
    let parfaitID: Int
    let textID: Int

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/texts/\(textID)" }
    var method: HTTPMethod { .delete }
}
