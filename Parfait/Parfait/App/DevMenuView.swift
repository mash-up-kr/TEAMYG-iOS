//
//  DevMenuView.swift
//  Parfait
//
//  Created by 김남수 on 8/12/26.
//

#if DEBUG
import SwiftUI
import Routing

/// DEBUG 전용 시작 화면 — 매 실행 여기서 시작점을 고른다:
/// 실제 로그인, 또는 개발용 토큰으로 그룹 직행.
/// RELEASE 의 자동로그인은 DEBUG 에선 자동 실행하지 않는다 — 이 메뉴가 가려지면
/// 토큰 삭제(자동로그인 해제)에 접근할 방법이 없기 때문.
struct DevMenuView: View {
    let router: any Router
    let diContainer: AppDependencies

    /// 저장된 토큰 유무 — '토큰 삭제' 활성화 판단.
    @State private var hasStoredAccessToken = false

    var body: some View {
        List {
            NavigationLink("실제 로그인", value: AppRoute.login)
            Button("개발용 토큰 로그인 — 그룹 화면부터 시작") {
                Task {
                    await diContainer.storeDevelopmentToken()
                    router.replaceStack(with: .group)
                }
            }
            Button("저장된 토큰 삭제 — 자동로그인 해제", role: .destructive) {
                Task {
                    await diContainer.clearStoredTokens()
                    hasStoredAccessToken = false
                }
            }
            .disabled(!hasStoredAccessToken)
        }
        .navigationTitle("시작점")
        .task {
            hasStoredAccessToken = await diContainer.hasStoredAccessToken()
        }
    }
}

#Preview {
    NavigationStack {
        DevMenuView(router: .preview, diContainer: AppDependencies())
    }
}
#endif
