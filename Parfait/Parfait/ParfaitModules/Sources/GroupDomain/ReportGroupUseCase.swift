//
//  ReportGroupUseCase.swift
//  GroupDomain
//
//  Created by 신상우 on 8/10/26.
//

/// 그룹을 신고한다. 정책상 신고가 접수되면 그룹에서 **자동으로 나가진다** —
/// 별도의 `leave` 호출 없이 이 요청 하나로 탈퇴까지 처리된다(S-103 신고 팝업 안내 문구).
public protocol ReportGroupUseCase: Sendable {
    func report(groupID: String) async throws
}

public struct ReportGroupUseCaseImpl: ReportGroupUseCase {
    private let groupRepository: any GroupRepository

    public init(groupRepository: any GroupRepository) {
        self.groupRepository = groupRepository
    }

    public func report(groupID: String) async throws {
        try await groupRepository.report(groupID: groupID)
    }
}
