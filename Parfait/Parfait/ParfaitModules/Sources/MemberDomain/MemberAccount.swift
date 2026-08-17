//
//  MemberAccount.swift
//  MemberDomain
//
//  Created by 김남수 on 8/17/26.
//

/// 내 계정 정보 엔티티 — 서버 `GET /api/v1/users/me` 응답에 대응.
public struct MemberAccount: Equatable, Sendable {
    public let id: Int
    public let provider: String
    public let nickname: String

    public init(id: Int, provider: String, nickname: String) {
        self.id = id
        self.provider = provider
        self.nickname = nickname
    }
}
