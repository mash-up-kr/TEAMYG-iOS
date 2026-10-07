//
//  PreviewGroupUseCase.swift
//  GroupFeature
//
//  Created by 신상우 on 8/16/26.
//

import Foundation
import GroupDomain

/// 프리뷰 전용 `GroupUseCase` 스텁 — 화면별로 흩어져 있던 행동별 스텁을 하나로 모았다.
/// 상세는 nil 이면, 참여는 에러가 설정되면 실패를 흉내낸다.
struct PreviewGroupUseCase: GroupUseCase {
    var detail: GroupDetail?
    var joinError: JoinGroupError?

    func fetchGroups() async throws -> [ParfaitGroup] { [] }

    func create(_ draft: GroupDraft) async throws {}

    func join(inviteCode: String) async throws -> JoinedGroup {
        if let joinError {
            throw joinError
        }
        return JoinedGroup(id: "preview-group", name: "그룹이름")
    }

    func fetchDetail(groupID: String) async throws -> GroupDetail {
        guard let detail else { throw CocoaError(.coderValueNotFound) }
        return detail
    }

    func changeNickname(groupID: String, nickname: String) async throws {}

    func leave(groupID: String) async throws {}

    func report(groupID: String) async throws {}
}
