//  App 레이어 = Xcode 앱 타깃. Composition Root(DI 조립 + 라우팅).
//  ParfaitModules 의 레이어들을 여기서 조립한다. (architecture.md)
//  ※ App 만은 모듈로 빼지 않고 앱 타깃에 직접 둔다 — 앱 타깃이 이미 최외곽 레이어.
import SwiftUI
import Routing
import LoginFeature
import GroupFeature
import CanvasFeature
import SettingFeature

/// 앱 루트 뷰. 라우팅(enum Route + NavigationStack)은 화면이 늘면 여기서 소유.
/// ponytail: 지금은 개발용 모듈 진입 리스트가 루트 — 실제 앱 플로우 확정 시 LoginView 루트로 복원.
struct RootView: View {
    @State private var diContainer = AppDependencies()
    @State private var router = AppRouter()

    /// 개발용 모듈 진입 목적지 — AppRoute 에 아직 없는 화면만 (있는 화면은 AppRoute value 로 직접 push).
    /// 뷰 기반 `NavigationLink { 뷰 }` 는 value 기반 push 와 섞이면 피처 내부 라우트 화면이
    /// 스택 아래로 끼어들어 전환이 깨지므로 리스트는 전부 value 기반으로 유지할 것.
    private enum DevModuleEntry: Hashable {
        case login, setting
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                NavigationLink("로그인 (LoginFeature)", value: DevModuleEntry.login)
                NavigationLink("약관 동의 (LoginFeature)", value: AppRoute.terms)
                NavigationLink("초대코드 입력 (GroupFeature)", value: AppRoute.group)
                NavigationLink("캔버스 (CanvasFeature)", value: AppRoute.canvas)
                NavigationLink("설정 (SettingFeature)", value: DevModuleEntry.setting)
            }
            .navigationTitle("모듈 진입")
            .navigationDestination(for: DevModuleEntry.self) { entry in
                switch entry {
                case .login:   LoginView(router: router, store: diContainer.makeLoginStore())
                case .setting: SettingView(store: diContainer.makeSettingStore())
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .group:  GroupView(makeInviteCodeStore: diContainer.makeInviteCodeStore)
                case .terms:  TermsView(router: router, store: diContainer.makeTermsStore())
                case .canvas: CanvasView()
                }
            }
        }
    }
}
