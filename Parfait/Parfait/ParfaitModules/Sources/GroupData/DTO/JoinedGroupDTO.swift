//
//  JoinedGroupDTO.swift
//  GroupData
//
//  Created by 박서연 on 10/6/26.
//

import GroupDomain

struct JoinedGroupDTO: Decodable, Sendable {
    let groupId: Int
    let groupName: String
}

extension JoinedGroupDTO {
    func toEntity() -> JoinedGroup {
        JoinedGroup(id: String(groupId), name: groupName)
    }
}
