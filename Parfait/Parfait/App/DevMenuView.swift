//
//  DevMenuView.swift
//  Parfait
//
//  Created by 김남수 on 8/12/26.
//

#if DEBUG
import SwiftUI
import Routing

/// DEBUG 전용 시작 화면 — 시작점은 두 개뿐이다:
/// 실제 로그인 플로우, 또는 개발용 토큰을 저장하고 그룹 화면부터 바로 시작.
struct DevMenuView: View {
    let router: any Router
    let diContainer: AppDependencies

    var body: some View {
        List {
            NavigationLink("실제 로그인", value: AppRoute.login)
            Button("개발용 토큰 로그인 — 그룹 화면부터 시작") {
                Task {
                    await diContainer.storeDevelopmentToken()
                    router.replaceStack(with: .group)
                }
            }
        }
        .navigationTitle("시작점")
    }
}

#Preview {
    NavigationStack {
        DevMenuView(router: .preview, diContainer: AppDependencies())
    }
}
#endif
