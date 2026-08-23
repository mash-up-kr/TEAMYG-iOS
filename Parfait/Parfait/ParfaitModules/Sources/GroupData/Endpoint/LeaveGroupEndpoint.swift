//
//  LeaveGroupEndpoint.swift
//  GroupData
//
//  Created by 신상우 on 8/20/26.
//

import Core

/// 그룹 나가기 (`DELETE /api/parfait-groups/{groupId}/members/me`).
/// 지우는 대상은 그룹이 아니라 **그 그룹의 내 멤버십**이다.
struct LeaveGroupEndpoint: Endpoint {
    let groupID: String

    var path: String { "/api/parfait-groups/\(groupID)/members/me" }
    var method: HTTPMethod { .delete }
}
