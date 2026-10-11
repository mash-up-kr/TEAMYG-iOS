//
//  CanvasNudgeBar.swift
//  CanvasFeature
//
//  Created by 박서연 on 10/9/26.
//

import SwiftUI
import UIComponent

struct CanvasNudgeBar: View {
    struct Action {
        let title: String
        let icon: Image
        let handler: () -> Void
    }

    /// 노출 유지 시간 — 이 시간이 지나면 자동으로 내려간다.
    static let displayDuration: Duration = .seconds(3)
    /// 위에서 내려오는 등장, 위로 올라가는 퇴장 슬라이드.
    static let slideAnimation: Animation = .easeInOut(duration: 0.3)

    let titleText: String
    let descriptionText: String
    var action: Action?

    var body: some View {
        HStack(spacing: .gap6) {
            message

            if let action {
                actionButton(action)
            }
        }
        .padding(.horizontal, .padding7)
        .padding(.vertical, .padding5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { Color.black75.allowsHitTesting(false) }
    }

    private var message: some View {
        VStack(alignment: .leading, spacing: .gap2) {
            Text(titleText)
                .suit(.body02SemiBold)
                .foregroundStyle(.cherry200)

            Text(descriptionText)
                .suit(.body02Regular)
                .foregroundStyle(.white75)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    private func actionButton(_ action: Action) -> some View {
        Button(action: action.handler) {
            HStack(spacing: .gap2) {
                Text(action.title)
                    .suit(.body02Regular)
                    .foregroundStyle(.gray950)

                action.icon
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(.gray950)
                    .frame(width: 16, height: 16)
            }
            .padding(.leading, .padding5)
            .padding(.trailing, .padding3)
            .padding(.vertical, .padding2)
            .background(.cherry100, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}
