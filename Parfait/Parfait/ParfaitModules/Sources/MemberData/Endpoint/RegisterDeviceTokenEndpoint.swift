//
//  RegisterDeviceTokenEndpoint.swift
//  MemberData
//
//  Created by 김남수 on 9/1/26.
//

import Core

/// 기기(FCM) 토큰 등록/갱신 (`POST /api/v1/notifications/devices`).
struct RegisterDeviceTokenEndpoint: Endpoint {
    let token: String

    var path: String { "/api/v1/notifications/devices" }
    var method: HTTPMethod { .post }
    var task: RequestTask { .body(Body(token: token, platform: "IOS")) }

    struct Body: Encodable, Sendable {
        let token: String
        let platform: String
    }
}
