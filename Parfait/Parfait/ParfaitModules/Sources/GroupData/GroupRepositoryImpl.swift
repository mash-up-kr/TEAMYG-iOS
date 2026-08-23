//
//  GroupRepositoryImpl.swift
//  GroupData
//
//  Created by 김남수 on 7/15/26.
//

import Core
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

    /// 내가 속한 그룹 목록 (`GET /api/parfait-groups`).
    ///
    /// 서버가 준 순서를 그대로 올린다 — 정렬은 UseCase 가 맡는다.
    public func fetchGroups() async throws -> [ParfaitGroup] {
        let groups: [MyParfaitGroupDTO] = try await request(FetchGroupsEndpoint())
        return groups.map { $0.toEntity() }
    }

    /// 그룹 생성 (`POST /api/parfait-groups`).
    ///
    /// 응답 본문(`groupId`·`groupName`·`inviteCode`·`memberLimit`)은 버린다. 생성 직후 화면은
    /// 목록으로 돌아가고 목록이 서버에서 다시 받아오므로 쓸 자리가 없다. 타입을 맞춰 두면
    /// 안 읽는 필드 때문에 디코딩이 깨질 수 있어, 형태를 보지 않는 `EmptyDTO` 로 받는다.
    public func create(_ draft: GroupDraft) async throws {
        do {
            let _: EmptyDTO = try await request(CreateGroupEndpoint(draft: draft))
        } catch is CancellationError {
            // 취소는 실패가 아니다. CreateGroupError 로 바꿔 버리면 호출부의
            // `catch is CancellationError` 를 못 타고 실패 알럿 경로로 빠진다.
            throw CancellationError()
        } catch {
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

    /// 그룹 상세 (`GET /api/parfait-groups/{groupId}`) — 사이드메뉴(S-101)가 그리는 단위.
    public func fetchDetail(groupID: String) async throws -> GroupDetail {
        let detail: GroupDetailDTO = try await request(GroupDetailEndpoint(groupID: groupID))
        return detail.toEntity()
    }

    /// 그룹 속 내 닉네임 변경 (`PATCH /api/parfait-groups/{groupId}/nickname`).
    ///
    /// 응답(`groupId`·`groupNickname`)은 방금 보낸 값이라 버린다 — 화면은 제출한 닉네임으로 갱신한다.
    public func changeMyNickname(groupID: String, nickname: String) async throws {
        do {
            let _: EmptyDTO = try await request(
                ChangeGroupNicknameEndpoint(groupID: groupID, nickname: nickname)
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // 사유를 나눠 봐야 쓸 곳이 없다 — 닉네임 규칙은 화면·UseCase 가 두 겹으로 먼저 막고,
            // 그 뒤 실패의 안내 문구는 디자인 미정이라 View 가 어느 사유든 같게 다룬다.
            throw ChangeGroupNicknameError.unknown
        }
    }

    /// 그룹 나가기 (`DELETE /api/parfait-groups/{groupId}/members/me`).
    /// 응답(`groupId`)은 방금 나간 그룹이라 버린다.
    public func leave(groupID: String) async throws {
        let _: EmptyDTO = try await request(LeaveGroupEndpoint(groupID: groupID))
    }

    /// 그룹 신고 (`POST /api/parfait-groups/{groupId}/reports`).
    /// 접수되면 서버가 탈퇴까지 처리한다 — 별도의 `leave` 호출이 필요 없다.
    /// 응답(`reportId`)은 화면에 쓰지 않아 버린다.
    public func report(groupID: String) async throws {
        let _: EmptyDTO = try await request(ReportGroupEndpoint(groupID: groupID))
    }
}

private extension GroupRepositoryImpl {
    /// 취소를 `CancellationError` 로 되돌려 주는 요청 래퍼.
    ///
    /// Alamofire 는 취소를 `AFError` 로 감싸 던져서, 그대로 올리면 Store 의
    /// `catch is CancellationError` 를 못 타고 실패 경로(에러 화면·실패 토스트)로 빠진다.
    /// 화면 이탈로 취소된 요청은 실패가 아니므로 에러 타입 대신 Task 상태를 보고 갈아끼운다.
    func request<Response: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> Response {
        do {
            return try await networkClient.request(endpoint)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw error
        }
    }
}
