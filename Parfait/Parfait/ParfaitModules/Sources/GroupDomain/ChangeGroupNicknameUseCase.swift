//
//  ChangeGroupNicknameUseCase.swift
//  GroupDomain
//
//  Created by 신상우 on 8/10/26.
//

import Common

/// 그룹 속 내 닉네임을 바꾸는 비즈니스 규칙. 정책 검증도 여기서 한 번 더 거친다 —
/// UI 가 막아주긴 하지만 규칙의 최종 판단은 Domain 이 갖는다 (`CreateGroupUseCase` 와 같은 방향).
public protocol ChangeGroupNicknameUseCase: Sendable {
    func changeNickname(groupID: String, nickname: String) async throws
}

public struct ChangeGroupNicknameUseCaseImpl: ChangeGroupNicknameUseCase {
    private let groupRepository: any GroupRepository

    public init(groupRepository: any GroupRepository) {
        self.groupRepository = groupRepository
    }

    public func changeNickname(groupID: String, nickname: String) async throws {
        // 닉네임은 앱 닉네임과 같은 공통 정책(`NicknameValidator`)을 그대로 쓴다.
        // 사유 대신 안내 문구를 돌려주는 검증기라 위반 여부만 본다.
        if NicknameValidator.errorMessage(for: nickname) != nil {
            throw ChangeGroupNicknameError.invalidNickname
        }
        try await groupRepository.changeMyNickname(groupID: groupID, nickname: nickname)
    }
}

/// 닉네임 변경 실패 사유. Data 레이어가 서버 에러 응답을 이 타입으로 매핑한다.
public enum ChangeGroupNicknameError: Error, Equatable {
    case invalidNickname
    /// 사유 불명(네트워크 단절 등) — View 가 일반 안내 문구로 렌더링.
    case unknown
}
