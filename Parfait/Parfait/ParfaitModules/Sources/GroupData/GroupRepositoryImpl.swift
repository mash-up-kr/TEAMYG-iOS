//
//  GroupRepositoryImpl.swift
//  GroupData
//
//  Created by 김남수 on 7/15/26.
//

import Foundation
import GroupDomain

public struct GroupRepositoryImpl: GroupRepository {

    public init() {}

    public func join(inviteCode: String) async throws {
        // ponytail: 서버 API 스펙 미정 — 확정 시 URLSession 호출 + 에러 응답→JoinGroupError 매핑 채움.
        print("초대코드 참여 스텁: length=\(inviteCode.count)")
    }

    // ponytail: 그룹 목록 API 스펙 미정 — 확정 시 URLSession 호출 + DTO→YGGroup 매핑으로 교체.
    //           지금은 화면을 붙여보기 위한 고정 스텁이다.
    public func fetchGroups() async throws -> [YGGroup] {
        Self.stubGroups
    }

    // ponytail: 그룹 생성 API 스펙 미정 — 확정 시 URLSession 호출 + 에러 응답→CreateGroupError 매핑 채움.
    //           지금은 방금 만든 것처럼 보이는 그룹을 즉석에서 만들어 돌려준다.
    public func create(_ draft: GroupDraft) async throws -> YGGroup {
        let now = Date()
        return YGGroup(
            id: "stub-created-\(UUID().uuidString)",
            name: draft.name,
            thumbnailURL: nil,
            lastActivityAt: now,
            createdAt: now,
            lastActorNametagType: .type1
        )
    }

    private static let stubGroups: [YGGroup] = {
        let names = ["매시업", "잠탈감금", "팀와지", "helloworld", "산책애호가"]
        let nametagTypes: [NametagType] = [.type9, .type3, .type1, .type11, .type5]
        let now = Date()
        return names.indices.map { index in
            YGGroup(
                id: "stub-group-\(index)",
                name: names[index],
                thumbnailURL: nil,
                lastActivityAt: now.addingTimeInterval(-180 * Double(index + 1)),
                createdAt: now.addingTimeInterval(-86_400 * Double(index + 1)),
                lastActorNametagType: nametagTypes[index]
            )
        }
    }()
}
