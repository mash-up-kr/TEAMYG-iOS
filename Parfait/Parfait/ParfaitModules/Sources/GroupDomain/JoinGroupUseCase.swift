//
//  JoinGroupUseCase.swift
//  GroupDomain
//
//  Created by 김남수 on 7/15/26.
//

/// 초대코드로 그룹에 참여하는 비즈니스 규칙.
public protocol JoinGroupUseCase: Sendable {
    func join(inviteCode: String) async throws
}

public struct JoinGroupUseCaseImpl: JoinGroupUseCase {
    private let groupRepository: any GroupRepository

    public init(groupRepository: any GroupRepository) {
        self.groupRepository = groupRepository
    }

    public func join(inviteCode: String) async throws {
        try await groupRepository.join(inviteCode: inviteCode)
    }
}
