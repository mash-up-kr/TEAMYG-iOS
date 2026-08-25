//
//  DevMenuView.swift
//  Parfait
//
//  Created by 김남수 on 8/12/26.
//

#if DEBUG
import SwiftUI
import Routing
import GroupFeature
import SettingFeature
import UIComponent

/// DEBUG 전용 시작 화면 — 매 실행 여기서 시작점을 고른다:
/// 실제 로그인, 또는 개발용 토큰으로 그룹 직행.
/// RELEASE 의 자동로그인은 DEBUG 에선 자동 실행하지 않는다 — 이 메뉴가 가려지면
/// 토큰 삭제(자동로그인 해제)에 접근할 방법이 없기 때문.
struct DevMenuView: View {
    let router: any Router
    let diContainer: AppDependencies
    /// 앱 전역 토스트 스택(RootView 소유) — 사이드메뉴 데모의 나가기/신고 확인 토스트가 쌓인다.
    @Binding var toasts: [YGToastItem]

    /// 저장된 토큰 유무 — '토큰 삭제' 활성화 판단.
    @State private var hasStoredAccessToken = false

    /// 실제 진입점이 아직 없는 화면의 개발용 목적지.
    private enum DevScreenEntry: Hashable {
        case groupSideMenu
        case setting
    }

    /// 사이드메뉴 데모가 열어 볼 개발 서버 그룹 — 개발용 토큰 계정이 속한 그룹이다.
    /// 상세를 서버에서 받아오므로 아무 문자열이나 넣으면 `GROUP_NOT_FOUND` 로 실패 화면만 뜬다.
    /// 개발 서버 데이터가 초기화되면 그룹을 다시 만들어 이 값만 바꾸면 된다.
    private static let demoGroupID = "25"
    /// 상세 응답이 오기 전 상단 바에 띄울 이름 — 응답이 오면 서버 값으로 바뀐다.
    private static let demoGroupName = "사이드메뉴데모"

    var body: some View {
        List {
            Button("실제 로그인") {
                router.replaceStack(with: .login)
            }
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

            Section("화면 데모") {
                NavigationLink("그룹 사이드메뉴 (GroupFeature)", value: DevScreenEntry.groupSideMenu)
                // 설정 API 는 인증 필요 — 개발용 토큰 로그인을 먼저 한 번 해두고 진입할 것.
                NavigationLink("설정 (SettingFeature)", value: DevScreenEntry.setting)
            }
        }
        .navigationTitle("시작점")
        .navigationDestination(for: DevScreenEntry.self) { entry in
            switch entry {
            case .groupSideMenu:
                // ponytail: 실제 진입점은 캔버스(C-001) 상단 바 사이드메뉴 버튼 — 연결되면 이 데모 항목 제거.
                //           나가기/신고 후 G-001 이동도 그때 이 콜백과 같은 방식으로 잇는다.
                GroupSideMenuView(
                    store: diContainer.makeGroupSideMenuStore(
                        groupID: Self.demoGroupID,
                        groupName: Self.demoGroupName
                    )
                ) { exitAction in
                    router.pop()
                    if let toastMessage = exitAction.completionToastMessage(groupName: Self.demoGroupName) {
                        toasts.append(YGToastItem(kind: .success, message: toastMessage))
                    }
                }
            case .setting:
                // ponytail: 실제 진입점(그룹/캔버스에서 설정 이동) 연결 전 개발용 — 연결되면 이 항목 제거.
                SettingView(
                    store: diContainer.makeSettingStore(),
                    makeAccountInfoStore: diContainer.makeAccountInfoStore
                )
            }
        }
        .task {
            hasStoredAccessToken = await diContainer.hasStoredAccessToken()
        }
    }
}

#Preview {
    NavigationStack {
        DevMenuView(router: .preview, diContainer: AppDependencies(), toasts: .constant([]))
    }
}
#endif
