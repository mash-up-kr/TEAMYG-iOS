//
//  GroupRepositoryImpl.swift
//  GroupData
//
//  Created by 김남수 on 7/15/26.
//

import Core
import Foundation
import GroupDomain

public struct GroupRepositoryImpl: GroupRepository {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    public func join(inviteCode: String) async throws {
        // ponytail: 서버 API 스펙 미정 — 확정 시 URLSession 호출 + 에러 응답→JoinGroupError 매핑 채움.
        print("초대코드 참여 스텁: length=\(inviteCode.count)")
    }

    // ponytail: 그룹 목록 API 스펙 미정 — 확정 시 URLSession 호출 + DTO→ParfaitGroup 매핑으로 교체.
    //           지금은 화면을 붙여보기 위한 고정 스텁이다.
    public func fetchGroups() async throws -> [ParfaitGroup] {
        Self.stubGroups
    }

    /// 그룹 생성 (`POST /api/parfait-groups`).
    ///
    /// 응답 본문(`groupId`·`groupName`·`inviteCode`·`memberLimit`)은 버린다. 생성 직후 화면은
    /// 목록으로 돌아가고 목록이 서버에서 다시 받아오므로 쓸 자리가 없다. 타입을 맞춰 두면
    /// 안 읽는 필드 때문에 디코딩이 깨질 수 있어, 형태를 보지 않는 `EmptyDTO` 로 받는다.
    public func create(_ draft: GroupDraft) async throws {
        do {
            let _: EmptyDTO = try await networkClient.request(
                CreateGroupEndpoint(draft: draft)
            )
        } catch {
            // 취소는 실패가 아니다. 여기서 CreateGroupError 로 바꿔 버리면 호출부의
            // `catch is CancellationError` 를 못 타고 실패 알럿 경로로 빠진다.
            // (Alamofire 는 취소를 AFError 로 감싸 던지므로 에러 타입 대신 Task 상태를 본다)
            if Task.isCancelled { throw CancellationError() }
            throw Self.createError(from: error)
        }
    }

    /// 서버 에러를 Domain 실패 사유로 옮긴다.
    ///
    /// 에러 코드를 사유별 케이스로 쪼개지 않는다. 그룹명·인원수는 화면과 UseCase 가 두 겹으로
    /// 먼저 막으므로, 서버 검증에 걸리는 건 클라이언트와 서버 규칙이 어긋났을 때뿐이다.
    /// 그때 필요한 건 무엇이 어긋났는지인데 그건 서버 문구가 가장 정확하다.
    /// 도메인 케이스로 접으면 View 가 일반 문구로 뭉개 단서가 사라진다.
    private static func createError(from error: any Error) -> CreateGroupError {
        guard
            let networkError = error as? NetworkError,
            case .server(_, let message, _) = networkError,
            let message
        else {
            return .unknown
        }
        return .server(message: message)
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
