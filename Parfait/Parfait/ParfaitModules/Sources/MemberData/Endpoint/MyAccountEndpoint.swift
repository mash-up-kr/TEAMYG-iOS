//
//  MyAccountEndpoint.swift
//  MemberData
//
//  Created by 김남수 on 8/17/26.
//

import Core

/// 내 계정 정보 조회 (`GET /api/v1/users/me`).
struct MyAccountEndpoint: Endpoint {
    var path: String { "/api/v1/users/me" }
    var method: HTTPMethod { .get }
}
