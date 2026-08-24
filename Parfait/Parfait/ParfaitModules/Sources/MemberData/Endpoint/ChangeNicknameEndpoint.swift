//
//  ChangeNicknameEndpoint.swift
//  MemberData
//
//  Created by 김남수 on 8/17/26.
//

import Core

/// 닉네임 변경 (`PATCH /api/v1/users/me/nickname`).
struct ChangeNicknameEndpoint: Endpoint {
    let nickname: String

    var path: String { "/api/v1/users/me/nickname" }
    var method: HTTPMethod { .patch }
    var task: RequestTask { .body(Body(nickname: nickname)) }

    struct Body: Encodable, Sendable {
        let nickname: String
    }
}
