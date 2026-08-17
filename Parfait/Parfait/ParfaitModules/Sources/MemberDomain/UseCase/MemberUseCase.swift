//
//  MemberUseCase.swift
//  MemberDomain
//
//  Created by 김남수 on 8/17/26.
//

/// 회원 계정 유스케이스 — 내 정보 조회·닉네임 변경·탈퇴.
public protocol MemberUseCase: Sendable {
    func fetchMyAccount() async throws -> MemberAccount
    func changeNickname(_ nickname: String) async throws -> String
    func withdraw() async throws
}

public struct MemberUseCaseImpl: MemberUseCase {
    private let memberRepository: any MemberRepository

    public init(memberRepository: any MemberRepository) {
        self.memberRepository = memberRepository
    }

    public func fetchMyAccount() async throws -> MemberAccount {
        try await memberRepository.fetchMyAccount()
    }

    public func changeNickname(_ nickname: String) async throws -> String {
        try await memberRepository.changeNickname(nickname)
    }

    public func withdraw() async throws {
        try await memberRepository.withdraw()
    }
}
