//
//  CanvasNudgeBar.swift
//  CanvasFeature
//
//  Created by 박서연 on 10/9/26.
//

import SwiftUI
import UIComponent

struct CanvasNudgeBar: View {
    enum ActionKind {
        case tap(() -> Void)
        /// 탭하면 공유 시트를 띄운다.
        case share(String)
    }

    struct Action {
        let title: String
        var icon: Image?
        let kind: ActionKind
    }

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
        .background(.black75)
        // 바 전체가 터치를 받아야 위로 스와이프 닫기가 아래 스크롤뷰에 뺏기지 않는다.
        .contentShape(.rect)
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
    }

    @ViewBuilder
    private func actionButton(_ action: Action) -> some View {
        switch action.kind {
        case .tap(let handler):
            Button(action: handler) {
                actionLabel(action)
            }
            .buttonStyle(.plain)
            .fixedSize()
        case .share(let item):
            ShareLink(item: item) {
                actionLabel(action)
            }
            .buttonStyle(.plain)
            .fixedSize()
        }
    }

    private func actionLabel(_ action: Action) -> some View {
        HStack(spacing: .gap2) {
            Text(action.title)
                .suit(.body02Regular)
                .foregroundStyle(.gray950)

            if let icon = action.icon {
                icon
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(.gray950)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.leading, .padding5)
        // 아이콘이 없으면 양옆 대칭
        .padding(.trailing, action.icon == nil ? .padding5 : .padding3)
        .padding(.vertical, .padding2)
        .background(.cherry100, in: .capsule)
        .contentShape(.capsule)
    }
}
