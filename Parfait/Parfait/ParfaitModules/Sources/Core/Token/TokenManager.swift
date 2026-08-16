//
//  TokenManager.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Foundation

/// 액세스/리프레시 토큰의 저장·조회·갱신 담당. Keychain 기반.
/// 인스턴스는 App 이 1회 생성해 주입한다 (전역 싱글톤 금지).
public actor TokenManager {
    private let networkClient: any NetworkClient
    private let keychain: TokenKeychainStore
    private var refreshTask: Task<Void, any Error>?

    /// 세션 종료(서버가 리프레시 토큰을 거절) 이벤트 스트림 — 단일 구독자 전제.
    /// App 루트가 구독해 로그인 화면으로 되돌린다.
    public let sessionExpirations: AsyncStream<Void>
    private let sessionExpirationContinuation: AsyncStream<Void>.Continuation

    /// - Parameter networkClient: 토큰 갱신(refresh) 전용 —
    ///   **인터셉터가 없는** 인스턴스를 넘겨야 한다 (refresh 가 401 을 맞았을 때 재귀 방지).
    public init(
        networkClient: any NetworkClient,
        keychainService: String = "com.teamyg.parfait.token"
    ) {
        self.networkClient = networkClient
        self.keychain = TokenKeychainStore(service: keychainService)
        (sessionExpirations, sessionExpirationContinuation) = AsyncStream.makeStream()
    }

    public var accessToken: String? {
        keychain.load(.accessToken)
    }

    public func update(accessToken: String, refreshToken: String) {
        keychain.save(accessToken, for: .accessToken)
        keychain.save(refreshToken, for: .refreshToken)
    }

    public func clear() {
        keychain.delete(.accessToken)
        keychain.delete(.refreshToken)
    }

    /// 세션 종료 — 토큰을 지우고 만료 이벤트를 보낸다.
    /// 서버가 리프레시 토큰 자체를 거절해 재로그인 외에 방법이 없을 때 호출한다.
    /// (로그아웃처럼 호출자가 직접 화면 전환하는 경우는 `clear()` 를 쓸 것)
    public func expireSession() {
        clear()
        sessionExpirationContinuation.yield()
    }

    /// 리프레시 토큰으로 토큰 쌍을 갱신한다.
    /// 동시에 여러 요청이 401 을 맞아도 갱신은 1회만 수행된다 (진행 중 Task 재사용).
    public func refresh() async throws {
        if let running = refreshTask {
            return try await running.value
        }
        guard let refreshToken = keychain.load(.refreshToken) else {
            throw NetworkError.unauthorized
        }
        let task = Task {
            let tokens: RefreshedTokensDTO = try await networkClient.request(
                RefreshEndpoint(refreshToken: refreshToken)
            )
            update(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        }
        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }
}
