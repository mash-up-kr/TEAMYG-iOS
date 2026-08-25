//
//  ChangeGroupNicknameEndpoint.swift
//  GroupData
//
//  Created by 신상우 on 8/20/26.
//

import Core

/// 그룹 속 내 닉네임 변경 (`PATCH /api/parfait-groups/{groupId}/nickname`).
///
/// 전역 닉네임(`PATCH /api/v1/users/me/nickname`)과 다른 API 다 — 이건 그룹 안에서만 쓰는 이름이다.
struct ChangeGroupNicknameEndpoint: Endpoint {
    let groupID: String
    let nickname: String

    var path: String { "/api/parfait-groups/\(groupID)/nickname" }
    var method: HTTPMethod { .patch }
    var task: RequestTask { .body(Body(groupNickname: nickname)) }

    struct Body: Encodable, Sendable {
        let groupNickname: String
    }
}
