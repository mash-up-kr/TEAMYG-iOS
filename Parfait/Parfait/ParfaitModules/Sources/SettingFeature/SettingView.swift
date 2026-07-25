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

    public init(store: SettingStore) {
        _store = State(initialValue: store)
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
        .navigationDestination(for: SettingRoute.self) { route in
            switch route {
            case .accountInfo:
                AccountInfoView(
                    store: AccountInfoStore(state: .init(nickname: store.state.nickname))
                )
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
            NavigationLink(value: SettingRoute.accountInfo) {
                navigationRowLabel("계정 정보")
            }
            .buttonStyle(.plain)
            navigationRow("서비스 이용약관") { store.send(.termsOfServiceTapped) }
            navigationRow("개인정보 처리 방침") { store.send(.privacyPolicyTapped) }
            versionRow
        }
    }

    private func navigationRow(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
        VStack(spacing: 0) {
            YGActionItem("로그아웃") { store.send(.logoutTapped) }
            DashedHorizontalLine()
                .stroke(Color.gray100, style: dashedStrokeStyle)
                .frame(height: 1)
            YGActionItem("서비스 탈퇴하기") { store.send(.withdrawTapped) }
        }
        .padding(.vertical, .padding2)
        .overlay {
            Rectangle()
                .strokeBorder(Color.gray100, style: dashedStrokeStyle)
        }
    }

    private var dashedStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 1, dash: [4, 4])
    }
}

/// 점선 가로줄. `Divider` 는 dash 를 지원하지 않아 직접 그린다.
private struct DashedHorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

#Preview {
    NavigationStack {
        SettingView(
            store: SettingStore(
                state: .init(
                    nickname: "아니야나그런데기니야",
                    loginProvider: "Kakao",
                    appVersion: "1.0v"
                )
            )
        )
    }
}
