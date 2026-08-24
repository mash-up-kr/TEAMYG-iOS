//
//  SettingView.swift
//  SettingFeature
//
//  Created by 김남수 on 7/21/26.
//

import SwiftUI
import UIComponent

public struct SettingView: View {
    @State private var store: SettingStore
    /// 계정 정보 화면 store 팩토리 — UseCase 주입은 App(Composition Root)이 담당한다.
    private let makeAccountInfoStore: (String) -> AccountInfoStore

    public init(
        store: SettingStore,
        makeAccountInfoStore: @escaping (String) -> AccountInfoStore
    ) {
        _store = State(initialValue: store)
        self.makeAccountInfoStore = makeAccountInfoStore
    }

    public var body: some View {
        VStack(spacing: .gap8) {
            profileCard
                .padding(.horizontal, .padding7)
            settingList
            dangerZone
                .padding(.horizontal, .padding7)
        }
        .ygTopBar(.detail(title: "설정"))
        .background(.whiteFixed)
        // 계정 정보에서 닉네임 변경 후 복귀 시에도 다시 조회되도록 task 가 아니라 onAppear
        .onAppear { store.send(.appeared) }
        .ygPopup(
            isPresented: store.binding(
                \.isWithdrawPopupPresented,
                SettingStore.Intent.withdrawPopupVisibilityChanged
            ),
            title: "파르페에서 탈퇴하시겠어요?",
            description: "지금까지 올린 사진은 익명으로 표시되며,\n삭제되지 않아요.",
            secondaryTitle: "탈퇴하기",
            primaryTitle: "그만두기",
            secondaryAction: { store.send(.withdrawConfirmed) }
        )
        .navigationDestination(for: SettingRoute.self) { route in
            switch route {
            case .accountInfo:
                AccountInfoView(store: makeAccountInfoStore(store.state.nickname))
            case .termsOfService:
                YGWebView(title: "서비스 이용약관", url: .termsOfService)
            case .privacyPolicy:
                YGWebView(title: "개인정보 처리 방침", url: .privacyPolicy)
            }
        }
    }

    // MARK: - 내 프로필 카드

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: .gap4) {
            Text("내 프로필")
                .suit(.body02Regular)
                .foregroundStyle(.gray400)

            VStack(alignment: .leading, spacing: .gap2) {
                Text(store.state.nickname)
                    .suit(.title03SemiBold)
                    .foregroundStyle(.gray900)
                Text(store.state.loginProvider)
                    .suit(.caption01Regular)
                    .foregroundStyle(.gray500)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.padding6)
        .background(.white75)
        .border(.cherry100, width: 1)
    }

    // MARK: - 설정 목록
    // ponytail: 행 UI 는 로컬 구현 — YGListItem(#42) 이 UIComponent 에 추가되면 교체

    private var settingList: some View {
        VStack(spacing: .gap3) {
            navigationRow("계정 정보", route: .accountInfo)
            navigationRow("서비스 이용약관", route: .termsOfService)
            navigationRow("개인정보 처리 방침", route: .privacyPolicy)
            versionRow
        }
    }

    private func navigationRow(_ title: String, route: SettingRoute) -> some View {
        NavigationLink(value: route) {
            navigationRowLabel(title)
        }
        .buttonStyle(.plain)
    }

    private func navigationRowLabel(_ title: String) -> some View {
        HStack(spacing: .gap2) {
            rowTitle(title)
            Spacer(minLength: 0)
            Image.icCaretRight
                .frame(width: 44, height: 44)
                .foregroundStyle(.gray300)
        }
        .padding(.horizontal, .padding7)
        .frame(height: 52)
        .contentShape(.rect)
    }

    private var versionRow: some View {
        HStack(spacing: .gap2) {
            rowTitle("버전 정보")
            Spacer(minLength: 0)
            Text(store.state.appVersion)
                .suit(.body02SemiBold)
                .foregroundStyle(.gray400)
        }
        .padding(.horizontal, .padding7)
        .frame(height: 52)
    }

    private func rowTitle(_ title: String) -> some View {
        Text(title)
            .suit(.body02Regular)
            .foregroundStyle(.gray800)
    }

    // MARK: - 위험 액션 (로그아웃·서비스 탈퇴)

    private var dangerZone: some View {
        YGDangerZone {
            YGActionItem("로그아웃") { store.send(.logoutTapped) }
            YGActionItem("서비스 탈퇴하기") { store.send(.withdrawTapped) }
        }
    }
}

// ponytail: 실제 약관·방침 주소 확정 전 임시 링크
private extension URL {
    static let termsOfService = URL(string: "https://www.apple.com/legal/internet-services/terms/site.html")!
    static let privacyPolicy = URL(string: "https://www.apple.com/legal/privacy/en-ww/")!
}

#Preview {
    NavigationStack {
        SettingView(
            store: SettingStore(
                memberUseCase: PreviewMemberUseCase(),
                authUseCase: PreviewAuthUseCase(),
                state: .init(
                    nickname: "아니야나그런데기니야",
                    loginProvider: "Kakao",
                    appVersion: "1.0v"
                )
            ),
            makeAccountInfoStore: { nickname in
                AccountInfoStore(
                    state: .init(nickname: nickname),
                    memberUseCase: PreviewMemberUseCase()
                )
            }
        )
    }
}
