//
//  GroupDetailEndpoint.swift
//  GroupData
//
//  Created by 신상우 on 8/20/26.
//

import Core

/// 그룹 상세 (`GET /api/parfait-groups/{groupId}`) — 사이드메뉴(S-101)가 그리는 단위.
struct GroupDetailEndpoint: Endpoint {
    let groupID: String

    var path: String { "/api/parfait-groups/\(groupID)" }
    var method: HTTPMethod { .get }
}
