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

    func makeTermsStore() -> TermsStore {
        TermsStore(
            policiesUseCase: PoliciesUseCaseImpl(authRepository: makeAuthRepository())
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
