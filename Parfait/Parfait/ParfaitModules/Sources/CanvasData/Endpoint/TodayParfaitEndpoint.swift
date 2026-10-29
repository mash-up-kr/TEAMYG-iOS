//
//  TodayParfaitEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import Core

/// 오늘 캔버스 조회 (`GET /api/v2/groups/{groupId}/parfaits/today`). 텍스트(`texts`)가 함께 온다 — 서버가 텍스트 연동용으로 낸 버전.
struct TodayParfaitEndpoint: Endpoint {
    let groupID: Int

    var path: String { "/api/v2/groups/\(groupID)/parfaits/today" }
    var method: HTTPMethod { .get }
}
