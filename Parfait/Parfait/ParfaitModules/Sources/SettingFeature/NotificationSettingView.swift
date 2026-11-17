//
//  NotificationSettingView.swift
//  SettingFeature
//
//  Created by 김남수 on 11/16/26.
//

import MemberDomain
import SwiftUI
import UIComponent

public struct NotificationSettingView: View {
    @State private var store: NotificationSettingStore
    @State private var toasts: [YGToastItem] = []
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    public init(store: NotificationSettingStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        VStack(spacing: .gap8) {
            if !store.state.isSystemNotificationAuthorized {
                systemNotificationOffCard
                    .padding(.horizontal, .padding7)
            }
            VStack(spacing: .gap3) {
                toggleRow(
                    "캔버스 알림 받기",
                    description: "아침 10시 오픈, 오후 8시 마감 알림을 보내드려요",
                    isOn: store.binding(
                        \.isDailyReminderEnabled,
                        NotificationSettingStore.Intent.dailyReminderToggled
                    )
                )
                toggleRow(
                    "활동 알림 모아 받기",
                    description: "그룹원 활동이 많아지면 모아서 한번에 보내드려요",
                    isOn: store.binding(
                        \.isActivityDigestEnabled,
                        NotificationSettingStore.Intent.activityDigestToggled
                    )
                )
            }
            .disabled(!store.state.isToggleEnabled)
            Spacer(minLength: 0)
        }
        // 탑바 아래 본문 영역에 얹어 토스트가 내비게이션 바 밑에서 내려오게 한다 — 내려오는 동안 바를 덮지 않도록 clip
        .ygToastOverlay($toasts)
        .clipped()
        .ygTopBar(.detail(title: "알림 설정"))
        .background(.whiteFixed)
        .onAppear { store.send(.appeared) }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { store.send(.sceneBecameActive) }
        }
        .task {
            for await event in store.events {
                switch event {
                case .saveFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "설정 저장에 실패했어요, 나중에 다시 시도해 주세요")
                    )
                }
            }
        }
    }

    // MARK: - 기기 알림 꺼짐 안내

    private var systemNotificationOffCard: some View {
        VStack(alignment: .leading, spacing: .gap4) {
            VStack(alignment: .leading, spacing: .gap2) {
                Text("기기 알림이 꺼져 있어요")
                    .suit(.body02SemiBold)
                    .foregroundStyle(.gray900)
                Text("알림을 받으려면 기기 설정에서 파르페 알림을 허용해 주세요")
                    .suit(.caption01Regular)
                    .foregroundStyle(.gray500)
            }
            YGButton("설정으로 이동", variant: .smallSquare) {
                store.send(.deviceSettingsTapped)
                // swiftlint:disable:next force_unwrapping
                openURL(URL(string: UIApplication.openNotificationSettingsURLString)!)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.padding6)
        .background(.white75)
        .border(.cherry100, width: 1)
    }

    // MARK: - 토글 행

    private func toggleRow(_ title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: .gap4) {
            ToggleRowLabel(title: title, description: description)
            YGSwitch(isOn: isOn)
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, .padding7)
        .padding(.vertical, .padding5)
    }
}

private struct ToggleRowLabel: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: .gap2) {
            Text(title)
                .suit(isEnabled ? .body02SemiBold : .body02Regular)
                .foregroundStyle(isEnabled ? .gray800 : .gray400)
            Text(description)
                .suit(.caption01Regular)
                .foregroundStyle(.gray400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("기기 알림 허용") {
    NavigationStack {
        NotificationSettingView(
            store: NotificationSettingStore(
                memberUseCase: PreviewMemberUseCase(),
                logAnalyticsEvent: { _ in },
                isSystemNotificationAuthorized: { true }
            )
        )
    }
}

#Preview("기기 알림 꺼짐") {
    NavigationStack {
        NotificationSettingView(
            store: NotificationSettingStore(
                memberUseCase: PreviewMemberUseCase(),
                logAnalyticsEvent: { _ in },
                isSystemNotificationAuthorized: { false }
            )
        )
    }
}
