//  App 레이어 = Xcode 앱 타깃. Composition Root(DI 조립 + 라우팅).
//  ParfaitModules 의 레이어들을 여기서 조립한다. (architecture.md)
//  ※ App 만은 모듈로 빼지 않고 앱 타깃에 직접 둔다 — 앱 타깃이 이미 최외곽 레이어.
import SwiftUI
import Routing
import LoginFeature
import GroupFeature
import CanvasFeature
import UIComponent

/// 앱 루트 뷰 — 실제 플로우만 조립한다. 스플래시 후 시작 화면은 로그인이고,
/// 저장된 토큰이 있으면 자동로그인으로 바로 그룹 화면에서 시작한다.
/// 로그인/회원가입 완료가 `replaceStack(with:)` 으로 스택을 재시작하면
/// 그 목적지가 새 루트가 된다(뒤로가기 불가).
struct RootView: View {
    @State private var diContainer = AppDependencies()
    @State private var router = AppRouter()
    /// 앱 전역 토스트 스택. 화면 전환 뒤에도 살아야 하는 토스트(예: 사이드메뉴 나가기 → G-001 확인)가 쌓인다.
    @State private var toasts: [YGToastItem] = []
    /// 스플래시(로고 애니메이션) 재생 중 — 끝나면 실제 시작 화면으로 교체한다.
    @State private var isPlayingSplash = true

    var body: some View {
        if isPlayingSplash {
            SplashView { isPlayingSplash = false }
                .task {
                    // 자동로그인: 스플래시 재생 동안 저장된 토큰을 확인해 루트를 미리 결정한다.
                    if await diContainer.hasStoredAccessToken() {
                        router.replaceStack(with: .group)
                    }
                }
        } else {
            mainFlow
        }
    }

    private var mainFlow: some View {
        NavigationStack(path: $router.path) {
            destination(for: router.rootRoute)
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
        // 화면 위 어떤 프레젠테이션보다 위 레이어 — 스택 전환과 무관하게 마지막(바깥쪽)에 선언한다.
        .ygToastOverlay($toasts)
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
                router: router,
                makeInviteCodeStore: diContainer.makeInviteCodeStore,
                makeCreateGroupStore: diContainer.makeCreateGroupStore
            )
        case .canvas:
            // ponytail: 캔버스가 서버에 붙으면 `groupID` 를 넘겨 그 그룹의 파르페를 조회한다 (#77).
            //           지금은 조립본의 의존성이 모두 스텁이라 어느 그룹이든 빈 캔버스가 뜬다.
            CanvasView(store: diContainer.makeCanvasStore())
        }
    }
}
