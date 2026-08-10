//
//  RefreshEndpoint.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Foundation

/// 토큰 재발급 API (`POST /api/v1/auth/reissue`). 단일 서버 전제로 Core 가 직접 정의한다.
struct RefreshEndpoint: Endpoint {
    let refreshToken: String

    var path: String { "/api/v1/auth/reissue" }
    var method: HTTPMethod { .post }
    var task: RequestTask { .body(Body(refreshToken: refreshToken)) }
    var requiresAuth: Bool { false }

    struct Body: Encodable, Sendable {
        let refreshToken: String
    }
}
