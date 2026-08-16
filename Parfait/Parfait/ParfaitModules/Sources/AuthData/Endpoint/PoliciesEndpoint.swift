//
//  PoliciesEndpoint.swift
//  AuthData
//
//  Created by 김남수 on 8/12/26.
//

import Core

/// 약관 목록 조회 (`GET /api/v1/policies`) — 회원가입 전 화면이라 인증 불필요.
struct PoliciesEndpoint: Endpoint {
    var path: String { "/api/v1/policies" }
    var method: HTTPMethod { .get }
    var requiresAuth: Bool { false }
}
