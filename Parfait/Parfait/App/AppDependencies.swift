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
import Common
import Core
import FirebaseMessaging
import Foundation
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
    /// 최근 업로드는 기기 파일 저장소 하나를 공유한다 — 저장(토핑 확정)과 조회(C-102)가 같은 곳을 봐야 한다.
    private let recentUploadsRepository = RecentUploadsRepositoryImpl()
    private let imageSession = URLSession(configuration: .imageTraffic)
    /// 캔버스를 나갔다 들어와도 토핑 이미지·테두리 실루엣 캐시가 살아 있도록 인스턴스 하나를 유지한다.
    private let canvasToppingRenderer: CanvasToppingRenderer

    init() {
        let tokenManager = TokenManager(networkClient: NetworkClientImpl())
        self.tokenManager = tokenManager
        self.networkClient = NetworkClientImpl(
            interceptor: TokenInterceptor(tokenManager: tokenManager)
        )
        canvasToppingRenderer = CanvasToppingRenderer(session: imageSession)
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

    func makeGroupSideMenuStore(groupID: String, groupName: String) -> GroupSideMenuStore {
        GroupSideMenuStore(
            groupID: groupID,
            groupName: groupName,
            groupUseCase: makeGroupUseCase()
        )
    }

    func makeToppingUseCase() -> ToppingUseCaseImpl {
        ToppingUseCaseImpl(
            imageUploadRepository: ImageUploadRepositoryImpl(networkClient: networkClient),
            toppingRepository: ToppingRepositoryImpl(networkClient: networkClient)
        )
    }

    func makeImageUploadRepository() -> ImageUploadRepositoryImpl {
        ImageUploadRepositoryImpl(networkClient: networkClient)
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

    /// 기기(FCM) 토큰 등록/갱신 — 세션이 생기는 시점(자동로그인·로그인·재로그인)에 App 루트가 호출한다.
    /// 토큰은 호출 시점에 FCM 에서 직접 조회한다(APNs 토큰이 아직이면 여기서 대기).
    func registerDeviceToken() async {
        do {
            // token() 은 deprecated 지만 대체제 register() 는 FCM 토큰을 아예 발급하지 않는
            // Installation ID 모델용이다 — 서버 계약이 토큰 기반인 동안은 이걸 쓴다.
            let token = try await Messaging.messaging().token()
            try await makeMemberUseCase().registerDeviceToken(token)
        } catch {
            // 실패해도 다음 로그인·앱 실행 때 재등록되므로 로그만 남긴다
            YGLogger.error("FCM 기기 토큰 등록 실패: \(error)")
        }
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

    func makeCanvasStore(groupID: Int, groupName: String) -> CanvasStore {
        CanvasStore(
            state: .init(groupName: groupName),
            dependencies: .init(
                groupID: groupID,
                canvasUseCase: CanvasUseCaseImpl(
                    canvasRepository: CanvasRepositoryImpl(networkClient: networkClient)
                ),
                canvasImageExporter: CanvasImageExporter(
                    toppingRenderer: canvasToppingRenderer,
                    session: imageSession
                )
            )
        )
    }

    func makeAlbumPickerStore(
        isLimited: Bool,
        showsRecentUploads: Bool,
        onPhotoConfirmed: @escaping (_ assetIdentifier: String) -> Void,
        onRecentUploadConfirmed: @escaping (StoredImage) -> Void
    ) -> AlbumPickerStore {
        AlbumPickerStore(
            isLimited: isLimited,
            showsRecentUploads: showsRecentUploads,
            recentUploadsRepository: recentUploadsRepository,
            onPhotoConfirmed: onPhotoConfirmed,
            onRecentUploadConfirmed: onRecentUploadConfirmed
        )
    }

    func makeRecentUploadsRepository() -> any RecentUploadsRepository {
        recentUploadsRepository
    }

    func makeCanvasToppingRenderer() -> CanvasToppingRenderer {
        canvasToppingRenderer
    }
}
