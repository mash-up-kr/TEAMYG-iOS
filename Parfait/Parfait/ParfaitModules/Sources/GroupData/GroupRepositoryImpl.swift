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

    // ponytail: 그룹 목록 API 스펙 미정 — 확정 시 URLSession 호출 + DTO→ParfaitGroup 매핑으로 교체.
    //           지금은 화면을 붙여보기 위한 고정 스텁이다.
    public func fetchGroups() async throws -> [ParfaitGroup] {
        Self.stubGroups
    }

    // ponytail: 그룹 생성 API 스펙 미정 — 확정 시 URLSession 호출 + 에러 응답→CreateGroupError 매핑 채움.
    //           지금은 방금 만든 것처럼 보이는 그룹을 즉석에서 만들어 돌려준다.
    public func create(_ draft: GroupDraft) async throws -> ParfaitGroup {
        let now = Date()
        return ParfaitGroup(
            id: "stub-created-\(UUID().uuidString)",
            name: draft.name,
            thumbnailURL: nil,
            lastActivityAt: now,
            createdAt: now,
            lastActorNametagType: .type1
        )
    }

    // ponytail: 그룹 상세 API 스펙 미정 — 확정 시 URLSession 호출 + DTO→GroupDetail 매핑으로 교체.
    //           지금은 사이드메뉴(S-101)를 붙여보기 위한 고정 스텁이다 (디자인 시안과 같은 11/12명 구성).
    public func fetchDetail(groupID: String) async throws -> GroupDetail {
        GroupDetail(
            id: groupID,
            name: "그룹이름",
            inviteCode: "WDIDCJ",
            memberLimit: 12,
            members: Self.stubMembers
        )
    }

    public func changeMyNickname(groupID: String, nickname: String) async throws {
        // ponytail: 닉네임 변경 API 스펙 미정 — 확정 시 URLSession 호출 + 에러 응답→ChangeGroupNicknameError 매핑 채움.
        print("그룹 닉네임 변경 스텁: groupID=\(groupID) length=\(nickname.count)")
    }

    public func leave(groupID: String) async throws {
        // ponytail: 그룹 나가기 API 스펙 미정 — 확정 시 URLSession 호출 채움.
        print("그룹 나가기 스텁: groupID=\(groupID)")
    }

    public func report(groupID: String) async throws {
        // ponytail: 그룹 신고 API 스펙 미정 — 확정 시 URLSession 호출 채움. (접수 시 서버가 탈퇴까지 처리)
        print("그룹 신고 스텁: groupID=\(groupID)")
    }

    private static let stubMembers: [GroupMember] = {
        let others = (1...10).map { index in
            GroupMember(
                id: "stub-member-\(index)",
                nickname: "아니야나그런데기니야기니라니까",
                nametagType: NametagType.allCases[index % NametagType.allCases.count],
                isMe: false
            )
        }
        return [GroupMember(id: "stub-member-me", nickname: "잠탈전용닉네임2", nametagType: .type4, isMe: true)] + others
    }()

    private static let stubGroups: [ParfaitGroup] = {
        let names = ["매시업", "잠탈감금", "팀와지", "helloworld", "산책애호가"]
        let nametagTypes: [NametagType] = [.type9, .type3, .type1, .type11, .type5]
        let now = Date()
        return names.indices.map { index in
            ParfaitGroup(
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
