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

    /// 내가 속한 그룹 전체. 정렬은 UseCase 가 맡는다.
    func fetchGroups() async throws -> [ParfaitGroup]

    /// 새 그룹 생성을 서버에 요청한다.
    /// 생성 직후 화면은 목록으로 돌아가고 목록이 서버에서 다시 받아오므로, 만들어진 그룹은 돌려주지 않는다.
    func create(_ draft: GroupDraft) async throws

    /// 그룹 상세(구성원·초대 코드) — 사이드메뉴(S-101)가 그리는 단위.
    func fetchDetail(groupID: String) async throws -> GroupDetail

    /// 그룹 속 내 닉네임 변경을 서버에 요청한다.
    /// 응답 스펙 미정 — 반환 타입은 백엔드 스펙 확정 시 추가.
    func changeMyNickname(groupID: String, nickname: String) async throws

    /// 그룹 나가기를 서버에 요청한다.
    func leave(groupID: String) async throws

    /// 그룹 신고를 서버에 요청한다. 접수되면 서버가 탈퇴까지 함께 처리한다.
    func report(groupID: String) async throws
}
