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
        // ponytail: 서버 API 스펙 미정 — 확정 시 URLSession 호출 + 에러 응답→JoinGroupError 매핑 채움.
        print("초대코드 참여 스텁: length=\(inviteCode.count)")
    }
}
