//
//  ParfaitDetailEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import Core

/// 캔버스 상세 조회 (`GET /api/v1/groups/{groupId}/parfaits/{parfaitId}`).
struct ParfaitDetailEndpoint: Endpoint {
    let groupID: Int
    let parfaitID: Int

    var path: String { "/api/v1/groups/\(groupID)/parfaits/\(parfaitID)" }
    var method: HTTPMethod { .get }
}
