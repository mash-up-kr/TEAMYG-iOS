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

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                NavigationLink("로그인 (LoginFeature)") {
                    LoginView(router: router, store: diContainer.makeLoginStore())
                }
                NavigationLink("약관 동의 (LoginFeature)") {
                    TermsView(router: router, store: diContainer.makeTermsStore())
                }
                NavigationLink("초대코드 입력 (GroupFeature)") {
                    GroupView(makeInviteCodeStore: diContainer.makeInviteCodeStore)
                }
                NavigationLink("캔버스 (CanvasFeature)") {
                    CanvasView()
                }
                NavigationLink("설정 (SettingFeature)") {
                    SettingView(store: diContainer.makeSettingStore())
                }
            }
            .navigationTitle("모듈 진입")
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
