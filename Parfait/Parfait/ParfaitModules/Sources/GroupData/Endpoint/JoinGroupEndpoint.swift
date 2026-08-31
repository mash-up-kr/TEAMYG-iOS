//
//  JoinGroupEndpoint.swift
//  GroupData
//
//  Created by 김남수 on 8/29/26.
//

import Core

/// 초대코드로 그룹 참여 (`POST /api/parfait-groups/join`).
struct JoinGroupEndpoint: Endpoint {
    let inviteCode: String

    var path: String { "/api/parfait-groups/join" }
    var method: HTTPMethod { .post }
    var task: RequestTask { .body(Body(inviteCode: inviteCode)) }

    struct Body: Encodable, Sendable {
        let inviteCode: String
    }
}
