//
//  DeleteToppingEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import Core

/// 토핑 삭제 (`DELETE /api/v1/groups/{groupId}/parfaits/{parfaitId}/images/{parfaitImageId}`).
struct DeleteToppingEndpoint: Endpoint {
    let groupID: Int
    let parfaitID: Int
    let toppingID: Int

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)/images/\(toppingID)" }
    var method: HTTPMethod { .delete }
}
