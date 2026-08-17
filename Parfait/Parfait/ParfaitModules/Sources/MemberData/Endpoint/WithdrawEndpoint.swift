//
//  WithdrawEndpoint.swift
//  MemberData
//
//  Created by 김남수 on 8/17/26.
//

import Core

/// 회원 탈퇴 (`DELETE /api/v1/users/me`) — 204 No Content 응답.
struct WithdrawEndpoint: Endpoint {
    var path: String { "/api/v1/users/me" }
    var method: HTTPMethod { .delete }
}
