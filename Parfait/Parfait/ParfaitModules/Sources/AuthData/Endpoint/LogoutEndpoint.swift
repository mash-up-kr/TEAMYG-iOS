//
//  LogoutEndpoint.swift
//  AuthData
//
//  Created by 김남수 on 8/17/26.
//

import Core

/// 로그아웃 (`POST /api/v1/auth/logout`) — 서버에서 리프레시 토큰을 무효화한다.
struct LogoutEndpoint: Endpoint {
    let refreshToken: String

    var path: String { "/api/v1/auth/logout" }
    var method: HTTPMethod { .post }
    var task: RequestTask {
        .body(Body(refreshToken: refreshToken))
    }

    struct Body: Encodable, Sendable {
        let refreshToken: String
    }
}
