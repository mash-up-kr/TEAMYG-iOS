//
//  FetchGroupsUseCase.swift
//  GroupDomain
//
//  Created by 신상우 on 8/1/26.
//

/// 소속 그룹 목록을 화면에 그릴 순서대로 돌려주는 비즈니스 규칙.
public protocol FetchGroupsUseCase: Sendable {
    func fetchGroups() async throws -> [YGGroup]
}

public struct FetchGroupsUseCaseImpl: FetchGroupsUseCase {
    private let groupRepository: any GroupRepository

    public init(groupRepository: any GroupRepository) {
        self.groupRepository = groupRepository
    }

    /// 최근 활동순. 밀리초까지 같으면 그룹 생성일시 최신순으로 가른다.
    /// 두 값이 모두 같아도 순서가 흔들리지 않도록 id 로 마지막 tie-break —
    /// 토핑 위치는 인덱스로 결정되므로 같은 데이터면 항상 같은 자리에 그려져야 한다.
    public func fetchGroups() async throws -> [YGGroup] {
        try await groupRepository.fetchGroups().sorted { lhs, rhs in
            if lhs.lastActivityAt != rhs.lastActivityAt {
                return lhs.lastActivityAt > rhs.lastActivityAt
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id < rhs.id
        }
    }
}
