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
        }
        .ygTopBar(.detail(title: "설정"))
        .background(.whiteFixed)
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
            navigationRow("계정 정보") { store.send(.accountInfoTapped) }
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
            HStack(spacing: .gap2) {
                rowTitle(title)
                Spacer(minLength: 0)
                Image.icCaretRight
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.gray300)
            }
            .padding(.horizontal, .padding7)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
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
}

#Preview {
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
