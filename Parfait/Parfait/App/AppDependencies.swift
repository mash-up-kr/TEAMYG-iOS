//
//  AppDependencies.swift
//  Parfait
//
//  Created by Enes on 6/25/26.
//

import AuthData
import AuthDomain
import CanvasData
import CanvasDomain
import CanvasFeature
import Core
import Foundation
import GroupData
import GroupDomain
import GroupFeature
import LoginFeature
import SettingFeature

/// 앱 시작 시 1회 조립하는 의존성 그래프. 싱글톤 아님 — 앱 루트가 소유.
struct AppDependencies {
    /// 토큰 갱신 전용 클라이언트(인터셉터 없음 — 401 재귀 방지) 위에 TokenManager 를 올리고,
    /// 본 클라이언트에 인증 헤더·401 재시도 인터셉터를 붙인다.
    private let tokenManager: TokenManager
    private let networkClient: any NetworkClient

    init() {
        let tokenManager = TokenManager(networkClient: NetworkClientImpl())
        self.tokenManager = tokenManager
        self.networkClient = NetworkClientImpl(
            interceptor: TokenInterceptor(tokenManager: tokenManager)
        )
    }

    /// 저장된 액세스 토큰 존재 여부 — 자동로그인(로그인 화면 스킵) 판단용.
    /// 만료 여부는 따지지 않는다: 만료된 액세스 토큰은 TokenInterceptor 가 첫 401 에서 자동 갱신하고,
    /// 리프레시까지 만료된 경우만 이후 요청이 실패한다.
    func hasStoredAccessToken() async -> Bool {
        await tokenManager.accessToken != nil
    }

    /// 세션 만료(서버가 리프레시 토큰 거절) 이벤트 스트림 — App 루트가 구독해 로그인으로 되돌린다.
    func sessionExpirations() async -> AsyncStream<Void> {
        await tokenManager.sessionExpirations
    }

    #if DEBUG
    /// 개발용 토큰 로그인 — 고정 액세스 토큰(개발 서버 계정)을 저장해 로그인 없이 그룹 화면부터 쓴다.
    /// 리프레시 토큰은 없으므로 액세스 토큰이 거절되면 세션 만료 → 로그인으로 돌아간다.
    func storeDevelopmentToken() async {
        await tokenManager.update(
            // swiftlint:disable:next line_length
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIyIiwidHlwZSI6IkFDQ0VTUyIsImlhdCI6MTc4NTY0MjAwMCwiZXhwIjoxODE3MTc4MDAwfQ.6PYljdcqu8YBYD9_HEU5smRbgZZWFhEnIyTTQ955Ni0",
            refreshToken: ""
        )
    }

    /// 저장된 토큰 삭제 — 다음 실행부터 자동로그인이 되지 않는다 (자동로그인 영구 해제).
    func clearStoredTokens() async {
        await tokenManager.clear()
    }
    #endif

    private func makeAuthRepository() -> AuthRepositoryImpl {
        AuthRepositoryImpl(networkClient: networkClient, tokenManager: tokenManager)
    }

    func makeLoginStore() -> LoginStore {
        LoginStore(
            socialLoginUseCase: SocialLoginUseCaseImpl(authRepository: makeAuthRepository())
        )
    }

    func makeGroupStore() -> GroupStore {
        GroupStore(
            fetchGroupsUseCase: FetchGroupsUseCaseImpl(groupRepository: GroupRepositoryImpl())
        )
    }

    func makeInviteCodeStore() -> InviteCodeStore {
        InviteCodeStore(
            joinGroupUseCase: JoinGroupUseCaseImpl(groupRepository: GroupRepositoryImpl())
        )
    }

    func makeCreateGroupStore() -> CreateGroupStore {
        CreateGroupStore(
            createGroupUseCase: CreateGroupUseCaseImpl(groupRepository: GroupRepositoryImpl())
        )
    }

    func makeTermsStore(registrationToken: String) -> TermsStore {
        let authRepository = makeAuthRepository()
        return TermsStore(
            registrationToken: registrationToken,
            policiesUseCase: PoliciesUseCaseImpl(authRepository: authRepository),
            signupUseCase: SignupUseCaseImpl(authRepository: authRepository)
        )
    }

    func makeSettingStore() -> SettingStore {
        SettingStore(state: .init(nickname: "닉네임", loginProvider: "소셜로그인", appVersion: "1.0v"))
    }

    func makeAlbumPickerStore(isLimited: Bool) -> AlbumPickerStore {
        AlbumPickerStore(
            isLimited: isLimited,
            recentUploadsRepository: RecentUploadsRepositoryImpl()
        )
    }
}
