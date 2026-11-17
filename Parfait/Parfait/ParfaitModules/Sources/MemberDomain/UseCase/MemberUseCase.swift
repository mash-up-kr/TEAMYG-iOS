//
//  MemberUseCase.swift
//  MemberDomain
//
//  Created by 김남수 on 8/17/26.
//

/// 회원 계정 유스케이스 — 내 정보 조회·닉네임 변경·탈퇴·알림 설정.
public protocol MemberUseCase: Sendable {
    func fetchMyAccount() async throws -> MemberAccount
    func changeNickname(_ nickname: String) async throws -> String
    func withdraw() async throws
    /// 기기(FCM) 토큰 등록/갱신.
    func registerDeviceToken(_ token: String) async throws
    /// 알림 설정 조회.
    func fetchNotificationSettings() async throws -> NotificationSettings
    /// 알림 설정 변경 — nil 인 항목은 서버 값을 유지한다. 서버가 확정한 전체 설정을 돌려준다.
    func updateNotificationSettings(
        isDailyReminderEnabled: Bool?,
        isActivityDigestEnabled: Bool?
    ) async throws -> NotificationSettings
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

    public func registerDeviceToken(_ token: String) async throws {
        try await memberRepository.registerDeviceToken(token)
    }

    public func fetchNotificationSettings() async throws -> NotificationSettings {
        try await memberRepository.fetchNotificationSettings()
    }

    public func updateNotificationSettings(
        isDailyReminderEnabled: Bool?,
        isActivityDigestEnabled: Bool?
    ) async throws -> NotificationSettings {
        try await memberRepository.updateNotificationSettings(
            isDailyReminderEnabled: isDailyReminderEnabled,
            isActivityDigestEnabled: isActivityDigestEnabled
        )
    }
}
