//
//  FetchGroupDetailUseCase.swift
//  GroupDomain
//
//  Created by 신상우 on 8/10/26.
//

/// 사이드메뉴(S-101)가 그릴 그룹 상세를 가져온다.
public protocol FetchGroupDetailUseCase: Sendable {
    func fetchDetail(groupID: String) async throws -> GroupDetail
}

public struct FetchGroupDetailUseCaseImpl: FetchGroupDetailUseCase {
    private let groupRepository: any GroupRepository

    public init(groupRepository: any GroupRepository) {
        self.groupRepository = groupRepository
    }

    public func fetchDetail(groupID: String) async throws -> GroupDetail {
        try await groupRepository.fetchDetail(groupID: groupID)
    }
}
