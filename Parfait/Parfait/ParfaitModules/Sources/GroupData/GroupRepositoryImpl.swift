//
//  GroupRepositoryImpl.swift
//  GroupData
//
//  Created by 김남수 on 7/15/26.
//

import GroupDomain

public struct GroupRepositoryImpl: GroupRepository {

    public init() {}

    public func join(inviteCode: String) async throws {
        // ponytail: 서버 API 스펙 미정 — 확정 시 여기에 URLSession 호출 채움.
        print("초대코드 참여 스텁: inviteCode=\(inviteCode)")
    }
}
