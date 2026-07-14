import SwiftUI

/// UIComponent(디자인 시스템) 데모 하네스.
/// 홈에서 테스트 시나리오를 골라 푸시로 진입한다. 시나리오 추가 = DemoHomeView 에 NavigationLink 한 줄 + 뷰 파일 하나.
@main
struct UIComponentDemoApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DemoHomeView()
            }
        }
    }
}

struct DemoHomeView: View {
    var body: some View {
        List {
            Section("디자인 토큰") {
                NavigationLink("Typography") { TypographyDemoView() }
                NavigationLink("Colors") { ColorsDemoView() }
                NavigationLink("Radius") { RadiusDemoView() }
                NavigationLink("Assets") { AssetsDemoView() }
            }
            Section("컴포넌트") {
                NavigationLink("YGTextField") { YGTextFieldDemoView() }
                NavigationLink("YGIconButton") { YGIconButtonDemoView() }
                NavigationLink("YGTab") { YGTabDemoView() }
            }
        }
        .navigationTitle("UIComponent Demo")
    }
}

#Preview {
    NavigationStack {
        DemoHomeView()
    }
}
