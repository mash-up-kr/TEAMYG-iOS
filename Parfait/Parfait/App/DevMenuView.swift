//
//  DevMenuView.swift
//  Parfait
//
//  Created by 김남수 on 8/12/26.
//

#if DEBUG
import SwiftUI
import Routing
import LoginFeature
import GroupFeature
import CanvasFeature
import SettingFeature

/// DEBUG 전용 시작 화면 — 실제 플로우(로그인부터) 또는 모듈별 화면으로 바로 들어간다.
/// 실제 플로우 목적지(AppRoute)는 RootView 가 조립하고, 여기는 개발용 진입만 소유한다.
struct DevMenuView: View {
    let router: any Router
    let diContainer: AppDependencies

    /// AppRoute 에 없는 개발용 진입 목적지 (AppRoute 에 있는 화면은 value 로 직접 push).
    /// 뷰 기반 `NavigationLink { 뷰 }` 는 value 기반 push 와 섞이면 피처 내부 라우트 화면이
    /// 스택 아래로 끼어들어 전환이 깨지므로 리스트는 전부 value 기반으로 유지할 것.
    private enum Entry: Hashable {
        case login, groupDemo, setting, album
    }

    var body: some View {
        List {
            Section("실제 플로우") {
                NavigationLink("로그인부터 시작", value: Entry.login)
            }
            Section("모듈별 진입") {
                // 개발용 직행이라 가입 토큰이 없다 — 확인(회원가입 완료)은 서버에서 거부된다.
                NavigationLink("약관 동의 (LoginFeature)", value: AppRoute.terms(registrationToken: ""))
                NavigationLink("그룹 목록 (GroupFeature)", value: AppRoute.group)
                // 그룹 수·실패 상태를 바꿔볼 수 있는 데모 래퍼.
                NavigationLink("그룹 목록 데모 (GroupFeature)", value: Entry.groupDemo)
                NavigationLink("캔버스 (CanvasFeature)", value: AppRoute.canvas)
                NavigationLink("앨범 (CanvasFeature)", value: Entry.album)
                NavigationLink("설정 (SettingFeature)", value: Entry.setting)
            }
        }
        .navigationTitle("모듈 진입")
        .navigationDestination(for: Entry.self) { entry in
            switch entry {
            case .login:
                LoginView(router: router, store: diContainer.makeLoginStore())
            case .groupDemo:
                GroupListDemoView(makeInviteCodeStore: diContainer.makeInviteCodeStore)
            case .setting:
                SettingView(store: diContainer.makeSettingStore())
            case .album:
                AlbumView(makeAlbumPickerStore: diContainer.makeAlbumPickerStore)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DevMenuView(router: .preview, diContainer: AppDependencies())
    }
}
#endif
