//
//  AppleLoginEndpoint.swift
//  AuthData
//
//  Created by 김남수 on 8/11/26.
//

import Core

/// 애플 로그인 (`POST /api/v1/auth/apple`).
struct AppleLoginEndpoint: Endpoint {
    let identityToken: String
    let nonce: String

    var path: String { "/api/v1/auth/apple" }
    var method: HTTPMethod { .post }
    var task: RequestTask {
        .body(Body(identityToken: identityToken, nonce: nonce))
    }
    var requiresAuth: Bool { false }

    struct Body: Encodable, Sendable {
        let identityToken: String
        let nonce: String
    }
}
