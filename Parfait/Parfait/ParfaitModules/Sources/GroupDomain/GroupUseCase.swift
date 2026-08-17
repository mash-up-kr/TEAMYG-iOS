//
//  GroupUseCase.swift
//  GroupDomain
//
//  Created by 신상우 on 8/16/26.
//

import Common

/// 그룹 도메인의 비즈니스 규칙 묶음. 행동별 타입으로 쪼개지 않고 도메인 단위로 모은다(팀 컨벤션).
/// 규칙의 최종 판단은 Domain 이 갖는다 — UI 가 막아주는 입력도 여기서 한 번 더 검증한다.
public protocol GroupUseCase: Sendable {
    /// 소속 그룹 목록을 화면에 그릴 순서대로 돌려준다.
    func fetchGroups() async throws -> [ParfaitGroup]

    /// 새 그룹을 만든다. 그룹명·닉네임·인원 규칙 검증을 거친다.
    /// 만들어진 그룹은 돌려주지 않는다 — 생성 직후 화면이 목록으로 돌아가고 목록이 서버에서 다시 받아온다.
    func create(_ draft: GroupDraft) async throws

    /// 초대코드로 그룹에 참여한다.
    func join(inviteCode: String) async throws

    /// 사이드메뉴(S-101)가 그릴 그룹 상세를 가져온다.
    func fetchDetail(groupID: String) async throws -> GroupDetail

    /// 그룹 속 내 닉네임을 바꾼다. 공통 닉네임 정책 검증을 거친다.
    func changeNickname(groupID: String, nickname: String) async throws

    /// 그룹에서 나간다. 나가도 그룹에 올렸던 사진은 지워지지 않는다(S-103 팝업 안내 문구의 근거 정책).
    func leave(groupID: String) async throws

    /// 그룹을 신고한다. 정책상 신고가 접수되면 **자동으로 나가진다** —
    /// 별도의 `leave` 호출 없이 이 요청 하나로 탈퇴까지 처리된다(S-103 신고 팝업 안내 문구).
    func report(groupID: String) async throws
}

public struct GroupUseCaseImpl: GroupUseCase {
    private let groupRepository: any GroupRepository

    public init(groupRepository: any GroupRepository) {
        self.groupRepository = groupRepository
    }

    /// 최근 활동순. 활동 이력이 없는 그룹(`lastActivityAt == nil`)은 뒤로 민다.
    ///
    /// 가를 수 없는 둘은 저장소가 준 순서를 그대로 둔다. `sorted(by:)` 는 안정 정렬을 보장하지
    /// 않으므로 원래 인덱스를 마지막 tie-break 로 명시한다 — 토핑이 놓일 자리는 목록 인덱스가
    /// 정하므로, 같은 데이터라면 새로고침해도 같은 자리에 그려져야 한다.
    ///
    /// ponytail: 정렬 2순위였던 그룹 생성일시가 서버 응답에 없어 규칙에서 뺐다 (#77).
    ///           지금은 활동 이력이 없는 그룹끼리 순서를 서버가 준 순서에 기대고 있다.
    public func fetchGroups() async throws -> [ParfaitGroup] {
        let groups = try await groupRepository.fetchGroups()
        return groups.enumerated()
            .sorted { lhs, rhs in
                switch (lhs.element.lastActivityAt, rhs.element.lastActivityAt) {
                case (let lhsActivityAt?, let rhsActivityAt?) where lhsActivityAt != rhsActivityAt:
                    return lhsActivityAt > rhsActivityAt
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                default:
                    return lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }

    public func create(_ draft: GroupDraft) async throws {
        if let violation = GroupNamePolicy.validate(draft.name) {
            throw CreateGroupError.invalidName(violation)
        }
        // 닉네임은 사유 대신 안내 문구를 돌려주는 검증기라 위반 여부만 본다 —
        // 여기까지 온 값은 UI 가 이미 막은 뒤라, 사유를 세분해도 쓸 곳이 없다.
        if NicknameValidator.errorMessage(for: draft.nickname) != nil {
            throw CreateGroupError.invalidNickname
        }
        guard GroupDraft.memberCountRange.contains(draft.memberCount) else {
            throw CreateGroupError.invalidMemberCount
        }
        try await groupRepository.create(draft)
    }

    public func join(inviteCode: String) async throws {
        try await groupRepository.join(inviteCode: inviteCode)
    }

    public func fetchDetail(groupID: String) async throws -> GroupDetail {
        try await groupRepository.fetchDetail(groupID: groupID)
    }

    public func changeNickname(groupID: String, nickname: String) async throws {
        // 닉네임은 앱 닉네임과 같은 공통 정책(`NicknameValidator`)을 그대로 쓴다.
        if NicknameValidator.errorMessage(for: nickname) != nil {
            throw ChangeGroupNicknameError.invalidNickname
        }
        try await groupRepository.changeMyNickname(groupID: groupID, nickname: nickname)
    }

    public func leave(groupID: String) async throws {
        try await groupRepository.leave(groupID: groupID)
    }

    public func report(groupID: String) async throws {
        try await groupRepository.report(groupID: groupID)
    }
}

/// 닉네임 변경 실패 사유. Data 레이어가 서버 에러 응답을 이 타입으로 매핑한다.
public enum ChangeGroupNicknameError: Error, Equatable {
    case invalidNickname
    /// 사유 불명(네트워크 단절 등) — View 가 일반 안내 문구로 렌더링.
    case unknown
}
