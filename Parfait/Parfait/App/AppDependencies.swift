//
//  AppDependencies.swift
//  Parfait
//
//  Created by Enes on 6/25/26.
//

import AuthData
import AuthDomain
import CanvasDomain
import CanvasFeature
import Core
import GroupData
import GroupDomain
import GroupFeature
import LoginFeature
import MemberData
import MemberDomain
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

    private func makeAuthUseCase() -> AuthUseCaseImpl {
        AuthUseCaseImpl(
            authRepository: AuthRepositoryImpl(
                networkClient: networkClient,
                tokenManager: tokenManager
            )
        )
    }

    func makeLoginStore() -> LoginStore {
        LoginStore(authUseCase: makeAuthUseCase())
    }

    func makeGroupStore() -> GroupStore {
        GroupStore(groupUseCase: makeGroupUseCase())
    }

    func makeInviteCodeStore() -> InviteCodeStore {
        InviteCodeStore(groupUseCase: makeGroupUseCase())
    }

    func makeCreateGroupStore() -> CreateGroupStore {
        CreateGroupStore(groupUseCase: makeGroupUseCase())
    }

    private func makeGroupUseCase() -> GroupUseCaseImpl {
        GroupUseCaseImpl(groupRepository: GroupRepositoryImpl(networkClient: networkClient))
    }

    func makeSettingStore() -> SettingStore {
        SettingStore(
            memberUseCase: makeMemberUseCase(),
            authUseCase: makeAuthUseCase(),
            state: .init(appVersion: "1.0v")
        )
    }

    func makeAccountInfoStore(nickname: String) -> AccountInfoStore {
        AccountInfoStore(state: .init(nickname: nickname), memberUseCase: makeMemberUseCase())
    }

    private func makeMemberUseCase() -> MemberUseCaseImpl {
        MemberUseCaseImpl(
            memberRepository: MemberRepositoryImpl(
                networkClient: networkClient,
                tokenManager: tokenManager
            )
        )
    }

    func makeTermsStore(registrationToken: String) -> TermsStore {
        TermsStore(
            registrationToken: registrationToken,
            authUseCase: makeAuthUseCase()
        )
    }

    func makeCanvasStore() -> CanvasStore {
        CanvasStore(
            dependencies: .init(
                loadCanvas: { _ in .empty },
                loadRecordedDates: { _ in [] },
                loadRecordedYears: { [] }
            )
        )
    }
}
