//
//  ParfaitYearsEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import Core

/// 캔버스 기록이 있는 연도 목록 (`GET /api/v1/groups/{groupId}/parfaits/year`).
struct ParfaitYearsEndpoint: Endpoint {
    let groupID: Int

    var path: String { "/api/v1/groups/\(groupID)/parfaits/year" }
    var method: HTTPMethod { .get }
}
