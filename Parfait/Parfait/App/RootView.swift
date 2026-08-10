//  App 레이어 = Xcode 앱 타깃. Composition Root(DI 조립 + 라우팅).
//  ParfaitModules 의 레이어들을 여기서 조립한다. (architecture.md)
//  ※ App 만은 모듈로 빼지 않고 앱 타깃에 직접 둔다 — 앱 타깃이 이미 최외곽 레이어.
import SwiftUI
import Routing
import LoginFeature
import GroupFeature
import CanvasFeature
import SettingFeature
import UIComponent

/// 앱 루트 뷰. 라우팅(enum Route + NavigationStack)은 화면이 늘면 여기서 소유.
/// ponytail: 지금은 개발용 모듈 진입 리스트가 루트 — 실제 앱 플로우 확정 시 LoginView 루트로 복원.
struct RootView: View {
    @State private var diContainer = AppDependencies()
    @State private var router = AppRouter()
    /// 앱 전역 토스트 스택. 화면 전환 뒤에도 살아야 하는 토스트(예: 사이드메뉴 나가기 → G-001 확인)가 쌓인다.
    @State private var toasts: [YGToastItem] = []

    /// 개발용 모듈 진입 목적지 — AppRoute 에 아직 없는 화면만 (있는 화면은 AppRoute value 로 직접 push).
    /// 뷰 기반 `NavigationLink { 뷰 }` 는 value 기반 push 와 섞이면 피처 내부 라우트 화면이
    /// 스택 아래로 끼어들어 전환이 깨지므로 리스트는 전부 value 기반으로 유지할 것.
    private enum DevModuleEntry: Hashable {
        case login, setting, groupSideMenu
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                NavigationLink("로그인 (LoginFeature)", value: DevModuleEntry.login)
                NavigationLink("약관 동의 (LoginFeature)", value: AppRoute.terms)
                NavigationLink("그룹 목록 (GroupFeature)", value: AppRoute.group)
                NavigationLink("캔버스 (CanvasFeature)", value: AppRoute.canvas)
                NavigationLink("설정 (SettingFeature)", value: DevModuleEntry.setting)
                NavigationLink("그룹 사이드메뉴 (GroupFeature)", value: DevModuleEntry.groupSideMenu)
            }
            .navigationTitle("모듈 진입")
            .navigationDestination(for: DevModuleEntry.self) { entry in
                switch entry {
                case .login:   LoginView(router: router, store: diContainer.makeLoginStore())
                case .setting: SettingView(store: diContainer.makeSettingStore())
                case .groupSideMenu:
                    // ponytail: 실제 진입점은 캔버스(C-001) 상단 바 사이드메뉴 버튼 — 화면이 생기면 연결.
                    //           나가기/신고 후 G-001 이동도 그때 이 콜백과 같은 방식으로 잇는다.
                    GroupSideMenuView(
                        store: diContainer.makeGroupSideMenuStore(groupID: "stub-group-0", groupName: "그룹이름")
                    ) { exitOutcome in
                        router.pop()
                        toasts.append(YGToastItem(kind: .success, message: exitOutcome.toastMessage))
                    }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .group:
                    #if DEBUG
                    // 개발 중에는 그룹 수·실패 상태를 바꿔볼 수 있는 데모 래퍼로 들어간다.
                    GroupListDemoView(makeInviteCodeStore: diContainer.makeInviteCodeStore)
                    #else
                    GroupView(
                        store: diContainer.makeGroupStore(),
                        makeInviteCodeStore: diContainer.makeInviteCodeStore,
                        makeCreateGroupStore: diContainer.makeCreateGroupStore
                    )
                    #endif
                case .terms:  TermsView(router: router, store: diContainer.makeTermsStore())
                case .canvas: CanvasView()
                }
            }
        }
        // 화면 위 어떤 프레젠테이션보다 위 레이어 — 스택 전환과 무관하게 마지막(바깥쪽)에 선언한다.
        .ygToastOverlay($toasts)
    }
}
