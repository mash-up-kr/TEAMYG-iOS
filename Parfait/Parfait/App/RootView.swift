//  App 레이어 = Xcode 앱 타깃. Composition Root(DI 조립 + 라우팅).
//  ParfaitModules 의 레이어들을 여기서 조립한다. (architecture.md)
//  ※ App 만은 모듈로 빼지 않고 앱 타깃에 직접 둔다 — 앱 타깃이 이미 최외곽 레이어.
import SwiftUI
import Data
import Domain
import Feature

/// 앱 시작 시 1회 조립하는 의존성 그래프. 싱글톤 아님 — 앱 루트가 소유.
final class AppDependencies {

    init() {
        
    }
}

/// 앱 루트 뷰. 라우팅(enum Route + NavigationStack)은 화면이 늘면 여기서 소유.
struct RootView: View {
    @State private var diContainer: AppDependencies = .init()

    init() {}

    var body: some View {
        Text("Hello")
    }
}
