//
//  CreateGroupEndpoint.swift
//  GroupData
//
//  Created by 신상우 on 8/17/26.
//

import Core
import GroupDomain

/// 그룹 생성 (`POST /api/parfait-groups`).
///
/// Domain 의 `GroupDraft` 와 서버 필드 이름이 서로 다르다 (`name`↔`groupName`,
/// `memberCount`↔`memberLimit`). 이름을 맞추는 대신 여기서 옮겨 담아, 서버 스펙 변화가
/// Domain 까지 번지지 않게 한다.
struct CreateGroupEndpoint: Endpoint {
    let draft: GroupDraft

    var path: String { "/api/parfait-groups" }
    var method: HTTPMethod { .post }
    var task: RequestTask {
        .body(
            Body(
                groupName: draft.name,
                groupNickname: draft.nickname,
                memberLimit: draft.memberCount
            )
        )
    }

    struct Body: Encodable, Sendable {
        let groupName: String
        let groupNickname: String
        let memberLimit: Int
    }
}
