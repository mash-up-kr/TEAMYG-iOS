//
//  TodayParfaitEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import Core

/// 오늘 캔버스 조회 (`GET /api/v1/groups/{groupId}/parfaits/today`).
struct TodayParfaitEndpoint: Endpoint {
    let groupID: Int

    var path: String { "/api/v1/groups/\(groupID)/parfaits/today" }
    var method: HTTPMethod { .get }
}
