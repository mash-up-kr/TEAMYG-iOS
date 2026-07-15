//
//  GroupRepository.swift
//  GroupDomain
//
//  Created by 김남수 on 7/15/26.
//

public protocol GroupRepository: Sendable {
    /// 초대코드로 그룹 참여를 서버에 요청한다.
    /// 응답 스펙 미정 — 반환 타입은 백엔드 스펙 확정 시 추가.
    func join(inviteCode: String) async throws
}
