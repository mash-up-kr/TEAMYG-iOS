//
//  FetchGroupsEndpoint.swift
//  GroupData
//
//  Created by 신상우 on 8/17/26.
//

import Core

/// 내가 속한 그룹 목록 (`GET /api/v2/parfait-groups`). 마지막 토핑이 사진인지 텍스트인지(`recentToppingType`)가 함께 온다.
///
/// 파라미터가 없다 — 누구의 목록인지는 Authorization 헤더의 토큰이 정한다.
struct FetchGroupsEndpoint: Endpoint {
    var path: String { "/api/v2/parfait-groups" }
    var method: HTTPMethod { .get }
}
