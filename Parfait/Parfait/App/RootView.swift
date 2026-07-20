//  App 레이어 = Xcode 앱 타깃. Composition Root(DI 조립 + 라우팅).
//  ParfaitModules 의 레이어들을 여기서 조립한다. (architecture.md)
//  ※ App 만은 모듈로 빼지 않고 앱 타깃에 직접 둔다 — 앱 타깃이 이미 최외곽 레이어.
import SwiftUI
import Routing
import LoginFeature
import GroupFeature
import CanvasFeature

/// 앱 루트 뷰. 라우팅(enum Route + NavigationStack)은 화면이 늘면 여기서 소유.
struct RootView: View {
    @State private var diContainer = AppDependencies()
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            LoginView(router: router, store: diContainer.makeLoginStore())
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .terms:  TermsView(router: router, store: diContainer.makeTermsStore())
                    case .group:  GroupView()
                    case .canvas: CanvasView()
                    }
                }
        }
    }
}
