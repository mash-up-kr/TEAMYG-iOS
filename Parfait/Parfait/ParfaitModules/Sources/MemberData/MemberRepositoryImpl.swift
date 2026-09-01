//
//  MemberRepositoryImpl.swift
//  MemberData
//
//  Created by 김남수 on 8/17/26.
//

import Core
import Foundation
import MemberDomain

/// MemberRepository 구현체 — 내 계정 조회·닉네임 변경·탈퇴.
public struct MemberRepositoryImpl: MemberRepository {
    private let networkClient: any NetworkClient
    private let tokenManager: TokenManager

    public init(networkClient: any NetworkClient, tokenManager: TokenManager) {
        self.networkClient = networkClient
        self.tokenManager = tokenManager
    }

    public func fetchMyAccount() async throws -> MemberAccount {
        let response: MyAccountResponseDTO = try await networkClient.request(MyAccountEndpoint())
        return MemberAccount(
            id: response.memberId,
            provider: response.provider,
            nickname: response.nickname
        )
    }

    public func changeNickname(_ nickname: String) async throws -> String {
        let response: ChangeNicknameResponseDTO = try await networkClient.request(
            ChangeNicknameEndpoint(nickname: nickname)
        )
        return response.nickname
    }

    public func withdraw() async throws {
        let _: EmptyDTO = try await networkClient.request(WithdrawEndpoint())
        // 탈퇴 성공 = 토큰 무효 → 세션 종료 이벤트로 App 루트가 로그인 화면 복귀
        await tokenManager.expireSession()
    }

    public func registerDeviceToken(_ token: String) async throws {
        let _: EmptyDTO = try await networkClient.request(RegisterDeviceTokenEndpoint(token: token))
    }
}
