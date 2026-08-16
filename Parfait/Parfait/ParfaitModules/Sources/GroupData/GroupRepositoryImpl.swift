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
    /// 응답에는 `groupId`·`groupName`·`inviteCode`·`memberLimit` 만 있고 목록용 필드
    /// (썸네일·마지막 활동 시각·마지막 활동자)는 없다. 방금 만든 그룹은 토핑도 활동 이력도
    /// 없으니 시각은 생성 시점으로 채우고 나머지는 비워 둔다 — 목록 화면이 다시 조회하면
    /// 서버 값으로 덮인다.
    public func create(_ draft: GroupDraft) async throws -> ParfaitGroup {
        do {
            let response: CreateGroupResponseDTO = try await networkClient.request(
                CreateGroupEndpoint(draft: draft)
            )
            let createdAt = Date()
            return ParfaitGroup(
                id: String(response.groupId),
                name: response.groupName,
                thumbnailURL: nil,
                lastActivityAt: createdAt,
                createdAt: createdAt,
                lastActorNametagType: .type1
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
    /// 인원 수는 서버 코드만으로 사유가 확정되지만, 그룹명은 어떤 규칙을 어겼는지 서버가
    /// 알려주지 않는다. `.invalidName` 은 사유를 하나 골라야 해서 없는 이유를 지어내게 되므로,
    /// 그룹명 오류는 서버 문구를 그대로 띄우는 `.server` 로 넘긴다.
    ///
    /// 두 코드 모두 UI 검증을 통과한 입력에서는 나오지 않는다 — 화면을 거치지 않는 호출이나
    /// 서버 규칙이 먼저 바뀐 경우를 위한 방어선이다.
    private static func createError(from error: any Error) -> CreateGroupError {
        guard
            let networkError = error as? NetworkError,
            case .server(let code, let message, _) = networkError
        else {
            return .unknown
        }
        switch code {
        case "INVALID_GROUP_MEMBER_LIMIT":
            return .invalidMemberCount
        default:
            return message.map { .server(message: $0) } ?? .unknown
        }
    }

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
