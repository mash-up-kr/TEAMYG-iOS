//  App 레이어 = Xcode 앱 타깃. Composition Root(DI 조립 + 라우팅).
//  ParfaitModules 의 레이어들을 여기서 조립한다. (architecture.md)
//  ※ App 만은 모듈로 빼지 않고 앱 타깃에 직접 둔다 — 앱 타깃이 이미 최외곽 레이어.
import SwiftUI
import Routing
import LoginFeature
import GroupFeature
import CanvasFeature
import SettingFeature

/// 앱 루트 뷰 — 실제 플로우만 조립한다. 시작 화면은 로그인이고,
/// 저장된 토큰이 있으면 자동로그인으로 바로 그룹 화면에서 시작한다.
/// 로그인/회원가입 완료가 `replaceStack(with:)` 으로 스택을 재시작하면
/// 그 목적지가 새 루트가 된다(뒤로가기 불가).
/// DEBUG 에서는 모듈별로 바로 들어가는 개발용 메뉴(`DevMenuView`)가 시작 화면
/// — 자동로그인은 건너뛴다(메뉴 진입을 막지 않기 위해).
struct RootView: View {
    @State private var diContainer = AppDependencies()
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            root
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .task {
            // 세션 만료(리프레시 토큰까지 거절) → 스택을 로그인으로 재시작한다.
            for await _ in await diContainer.sessionExpirations() {
                router.replaceStack(with: .login)
            }
        }
    }

    @ViewBuilder
    private var root: some View {
        if let rootRoute = router.rootRoute {
            destination(for: rootRoute)
        } else {
            #if DEBUG
            DevMenuView(router: router, diContainer: diContainer)
            #else
            destination(for: .login)
                .task {
                    // 자동로그인: 저장된 토큰이 있으면 로그인 화면을 건너뛴다.
                    // 세션 만료로 돌아온 로그인(rootRoute == .login)에는 붙지 않는다 — 최초 진입 전용.
                    if await diContainer.hasStoredAccessToken() {
                        router.replaceStack(with: .group)
                    }
                }
            #endif
        }
    }

    /// 피처 간 이동 목적지(AppRoute) → 화면 조립. 실제 플로우: 로그인 → 약관 동의 → 그룹.
    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .login:
            LoginView(router: router, store: diContainer.makeLoginStore())
        case .terms(let registrationToken):
            TermsView(
                router: router,
                store: diContainer.makeTermsStore(registrationToken: registrationToken)
            )
        case .group:
            GroupView(
                store: diContainer.makeGroupStore(),
                makeInviteCodeStore: diContainer.makeInviteCodeStore,
                makeCreateGroupStore: diContainer.makeCreateGroupStore
            )
        case .canvas:
            CanvasView()
        }
    }
}
