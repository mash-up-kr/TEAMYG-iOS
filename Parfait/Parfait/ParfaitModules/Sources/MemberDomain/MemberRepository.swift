//
//  MemberRepository.swift
//  MemberDomain
//
//  Created by 김남수 on 8/17/26.
//

/// 회원 계정 데이터 접근 계약.
public protocol MemberRepository: Sendable {
    func fetchMyAccount() async throws -> MemberAccount
    /// 변경 성공 시 서버가 확정한 닉네임을 돌려준다.
    func changeNickname(_ nickname: String) async throws -> String
    /// 회원 탈퇴 — 성공 시 로컬 세션도 종료된다.
    func withdraw() async throws
    /// 기기(FCM) 토큰 등록/갱신.
    func registerDeviceToken(_ token: String) async throws
}
