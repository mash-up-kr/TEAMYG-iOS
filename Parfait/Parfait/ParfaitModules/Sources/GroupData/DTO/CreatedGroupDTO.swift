//
//  CreatedGroupDTO.swift
//  GroupData
//
//  Created by 박서연 on 8/29/26.
//

import GroupDomain

/// 그룹 생성 응답 (`POST /api/parfait-groups`).
///
/// 응답에는 `groupName`·`memberLimit` 도 오지만 화면이 이미 아는 값이라 받지 않는다.
/// `Decodable` 은 선언하지 않은 키를 무시하므로 서버가 필드를 더 늘려도 깨지지 않는다.
struct CreatedGroupDTO: Decodable, Sendable {
    let groupId: Int
    let inviteCode: String
}

extension CreatedGroupDTO {
    func toEntity(memberCount: Int) -> CreatedGroup {
        CreatedGroup(id: String(groupId), inviteCode: inviteCode, memberCount: memberCount)
    }
}
