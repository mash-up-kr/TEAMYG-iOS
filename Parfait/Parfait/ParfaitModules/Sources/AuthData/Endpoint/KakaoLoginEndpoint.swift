//
//  KakaoLoginEndpoint.swift
//  AuthData
//
//  Created by 김남수 on 8/11/26.
//

import Core

/// 카카오 로그인 (`POST /api/v1/auth/kakao`).
struct KakaoLoginEndpoint: Endpoint {
    let idToken: String
    let nonce: String

    var path: String { "/api/v1/auth/kakao" }
    var method: HTTPMethod { .post }
    var task: RequestTask { .body(Body(idToken: idToken, nonce: nonce)) }
    var requiresAuth: Bool { false }

    struct Body: Encodable, Sendable {
        let idToken: String
        let nonce: String
    }
}
