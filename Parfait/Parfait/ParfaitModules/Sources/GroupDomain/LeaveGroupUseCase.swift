//
//  LeaveGroupUseCase.swift
//  GroupDomain
//
//  Created by 신상우 on 8/10/26.
//

/// 그룹에서 나간다. 나가도 그룹에 올렸던 사진은 지워지지 않는다(S-103 팝업 안내 문구의 근거 정책).
public protocol LeaveGroupUseCase: Sendable {
    func leave(groupID: String) async throws
}

public struct LeaveGroupUseCaseImpl: LeaveGroupUseCase {
    private let groupRepository: any GroupRepository

    public init(groupRepository: any GroupRepository) {
        self.groupRepository = groupRepository
    }

    public func leave(groupID: String) async throws {
        try await groupRepository.leave(groupID: groupID)
    }
}
