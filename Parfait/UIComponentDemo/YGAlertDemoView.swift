//
//  YGAlertDemoView.swift
//  UIComponentDemo
//
//  Created by 신상우 on 7/17/26.
//

import SwiftUI
import UIComponent

/// YGAlert 인터랙티브 데모.
/// `.ygAlert(item:)` 는 선언 순서와 무관하게 같은 계층의 YGTopBar 를 찾아
/// 그 아래 레이어에서 알림을 내린다.
/// 닫기: 위로 스와이프 or 2.5초 경과 (Figma 805-4997 닫기 정책).
struct YGAlertDemoView: View {
    private struct AlertConfiguration: Equatable {
        let id = UUID() // 프레젠테이션마다 고유 → 같은 시나리오 재탭도 타이머가 다시 시작
        var title: String
        var subtitle: String
        var titleColor: Color = .cherry200
        var hasAction: Bool
    }

    @Environment(\.dismiss) private var dismiss

    @State private var presentedAlert: AlertConfiguration?
    @State private var actionTapCount = 0

    var body: some View {
        List {
            Section("시나리오 (탭하면 탑바 아래에서 노출)") {
                Button("액션 칩 포함 (728-4573)") {
                    present(.init(title: "제로", subtitle: "메모지를 남겼어요", hasAction: true))
                }
                Button("텍스트 전용 (1023-2935)") {
                    present(.init(title: "제로", subtitle: "메모지를 남겼어요", hasAction: false))
                }
                Button("titleColor 주입 (Nametag 타입 매핑)") {
                    present(.init(title: "메론", subtitle: "입장했어요", titleColor: .melon500, hasAction: false))
                }
                Button("긴 텍스트") {
                    present(.init(
                        title: "아주아주아주아주아주아주 긴 닉네임",
                        subtitle: "아주아주아주아주아주아주 긴 행동 설명입니다",
                        hasAction: true
                    ))
                }
            }

            Section("상태") {
                Text("액션 탭 횟수: \(actionTapCount)")
                Text("닫기: 위로 스와이프 or 2.5초 경과")
                    .foregroundStyle(.gray400)
                Text("표시 중 다른 시나리오를 누르면 내용이 바뀌고 2.5초를 다시 기다린다")
                    .foregroundStyle(.gray400)
            }
        }
        .ygTopBar(.detail(title: "YGAlert"), onLeadingTap: { dismiss() })
        .ygAlert(item: $presentedAlert) { configuration in
            YGAlert(
                title: configuration.title,
                subtitle: configuration.subtitle,
                titleColor: configuration.titleColor,
                action: configuration.hasAction ? .init("보기") { actionTapCount += 1 } : nil
            )
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func present(_ newConfiguration: AlertConfiguration) {
        presentedAlert = newConfiguration
    }
}

#Preview {
    NavigationStack {
        YGAlertDemoView()
    }
}
