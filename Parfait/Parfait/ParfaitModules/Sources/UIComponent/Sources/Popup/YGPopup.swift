//
//  YGPopup.swift
//  UIComponent
//
//  Created by 김남수 on 7/17/26.
//

import SwiftUI

/// 경고 팝업. 전체 화면 딤(black25) 위에 312×215 고정 카드를 센터 정렬로 띄운다.
/// 사용: 표시할 화면에 `.overlay { if showsPopup { YGPopup(...) } }` 또는 fullScreenCover.
public struct YGPopup: View {
    private let icon: Image
    private let title: String
    private let description: String
    private let secondaryTitle: String
    private let primaryTitle: String
    private let secondaryAction: () -> Void
    private let primaryAction: () -> Void

    public init(
        icon: Image,
        title: String,
        description: String,
        secondaryTitle: String,
        primaryTitle: String,
        secondaryAction: @escaping () -> Void,
        primaryAction: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.secondaryTitle = secondaryTitle
        self.primaryTitle = primaryTitle
        self.secondaryAction = secondaryAction
        self.primaryAction = primaryAction
    }

    public var body: some View {
        ZStack {
            Color.black25.ignoresSafeArea()
            card
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            VStack(spacing: .gap2) {
                icon
                    .resizable()
                    .foregroundStyle(.cherry600)
                    .frame(width: 48, height: 48)
                Text(title)
                    .suit(.title03SemiBold)
                    .foregroundStyle(.gray900)
                    .lineLimit(1)
                Text(description)
                    .suit(.body02Regular)
                    .foregroundStyle(.gray500)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            HStack(spacing: .gap3) {
                YGButton(secondaryTitle, variant: .mediumSecondary, action: secondaryAction)
                YGButton(primaryTitle, variant: .mediumPrimary, action: primaryAction)
            }
        }
        .padding(.horizontal, .padding6)
        .padding(.top, .padding5)
        .padding(.bottom, .padding6)
        .frame(width: 312, height: 215)
        .background(.whiteFixed)
    }
}

#Preview {
    ZStack {
        Color.orange.ignoresSafeArea() // 딤 확인용
        YGPopup(
            icon: .icWarningRound,
            title: "그룹을 나가시겠어요?",
            description: "지금까지 쌓은 체리가 모두 사라져요.\n그래도 나가시겠어요?",
            secondaryTitle: "취소",
            primaryTitle: "나가기",
            secondaryAction: {},
            primaryAction: {}
        )
    }
}
