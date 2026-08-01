//
//  CreateGroupUseCase.swift
//  GroupDomain
//
//  Created by 신상우 on 8/1/26.
//

/// 새 그룹을 만드는 비즈니스 규칙. 이름 규칙 검증도 여기서 한 번 더 거친다 —
/// UI 가 막아주긴 하지만 규칙의 최종 판단은 Domain 이 갖는다.
public protocol CreateGroupUseCase: Sendable {
    func create(_ draft: GroupDraft) async throws -> YGGroup
}

public struct CreateGroupUseCaseImpl: CreateGroupUseCase {
    private let groupRepository: any GroupRepository

    public init(groupRepository: any GroupRepository) {
        self.groupRepository = groupRepository
    }

    public func create(_ draft: GroupDraft) async throws -> YGGroup {
        if let violation = GroupNamePolicy.groupName.validate(draft.name) {
            throw CreateGroupError.invalidName(violation)
        }
        if let violation = GroupNamePolicy.nickname.validate(draft.nickname) {
            throw CreateGroupError.invalidNickname(violation)
        }
        guard GroupDraft.memberCountRange.contains(draft.memberCount) else {
            throw CreateGroupError.invalidMemberCount
        }
        return try await groupRepository.create(draft)
    }
}

/// 그룹 생성 입력 한 벌. 세 값이 항상 함께 움직여서 파라미터를 늘리는 대신 묶어 둔다.
public struct GroupDraft: Sendable, Equatable {
    /// 그룹 인원으로 고를 수 있는 범위 (A-005 그리드 1~12).
    public static let memberCountRange = 1...12

    public let name: String
    public let nickname: String
    public let memberCount: Int

    public init(name: String, nickname: String, memberCount: Int) {
        self.name = name
        self.nickname = nickname
        self.memberCount = memberCount
    }
}

/// 그룹 생성 실패 사유. Data 레이어가 서버 에러 응답을 이 타입으로 매핑한다.
public enum CreateGroupError: Error, Equatable {
    case invalidName(GroupNameViolation)
    case invalidNickname(GroupNameViolation)
    case invalidMemberCount
    /// 같은 이름의 그룹을 이미 갖고 있다.
    case duplicatedName
    /// 매핑되지 않은 서버 에러 — 서버가 내려준 메시지를 그대로 전달.
    case server(message: String)
    /// 사유 불명(네트워크 단절 등) — View 가 일반 안내 문구로 렌더링.
    case unknown
}
