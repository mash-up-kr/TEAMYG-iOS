//
//  FetchGroupsEndpoint.swift
//  GroupData
//
//  Created by 신상우 on 8/17/26.
//

import Core

/// 내가 속한 그룹 목록 (`GET /api/parfait-groups`).
///
/// 파라미터가 없다 — 누구의 목록인지는 Authorization 헤더의 토큰이 정한다.
struct FetchGroupsEndpoint: Endpoint {
    var path: String { "/api/parfait-groups" }
    var method: HTTPMethod { .get }
}
