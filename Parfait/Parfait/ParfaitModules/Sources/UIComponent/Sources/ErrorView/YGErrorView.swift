//
//  YGErrorView.swift
//  UIComponent
//
//  Created by 김남수 on 8/21/26.
//

import SwiftUI

/// 에러 상태 안내 뷰. 경고 아이콘 + 제목 + 설명, 필요 시 하단 액션 버튼.
/// 배치(중앙 정렬 등)는 사용하는 쪽이 결정한다.
public struct YGErrorView: View {
    /// 어떤 배경 위에 놓이는지에 따라 글자·버튼 색이 달라진다.
    public enum Tone {
        /// 밝은 배경 위 (기본).
        case light
        /// 검정 딤(black75) 위 — C-001-Error 오버레이처럼 화면을 덮을 때.
        case onDim
    }

    private let tone: Tone
    private let title: String
    private let message: String
    private let buttonTitle: String?
    private let action: () -> Void
    private let secondaryButtonTitle: String?
    private let secondaryAction: () -> Void

    /// - Parameters:
    ///   - tone: 놓이는 배경 톤. 기본은 밝은 배경.
    ///   - buttonTitle: 값을 주면 하단에 버튼 노출 (예: "새로고침"). `nil` 이면 버튼 없음.
    ///   - action: 버튼 탭 동작. `buttonTitle` 이 `nil` 이면 무시된다.
    ///   - secondaryButtonTitle: 값을 주면 첫 버튼 아래에 보조 버튼 노출. `buttonTitle` 이 `nil` 이면 무시된다.
    ///   - secondaryAction: 보조 버튼 탭 동작. `secondaryButtonTitle` 이 `nil` 이면 무시된다.
    public init(
        tone: Tone = .light,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        action: @escaping () -> Void = {},
        secondaryButtonTitle: String? = nil,
        secondaryAction: @escaping () -> Void = {}
    ) {
        self.tone = tone
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryAction = secondaryAction
    }

    public var body: some View {
        VStack(spacing: .gap7) {
            VStack(spacing: .gap3) {
                Image.icWarningRound
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color.cherry600)

                VStack(spacing: .gap1) {
                    Text(title)
                        .suit(.title03SemiBold)
                        .foregroundStyle(titleColor)
                    Text(message)
                        .suit(.body02Regular)
                        .foregroundStyle(messageColor)
                }
                .multilineTextAlignment(.center)
            }

            if let buttonTitle {
                VStack(spacing: .gap3) {
                    YGButton(buttonTitle, variant: primaryButtonVariant, action: action)
                    if let secondaryButtonTitle {
                        YGButton(secondaryButtonTitle, variant: .mediumSecondary, action: secondaryAction)
                    }
                }
            }
        }
    }

    private var titleColor: Color {
        switch tone {
        case .light: .gray900
        case .onDim: .gray100
        }
    }

    private var messageColor: Color {
        switch tone {
        case .light: .gray500
        case .onDim: .gray300
        }
    }

    /// 딤 위에서는 어두운 Primary 버튼이 묻힌다 — 시안(C-001-Error)대로 밝은 Secondary 를 쓴다.
    private var primaryButtonVariant: YGButton.Variant {
        switch tone {
        case .light: .mediumPrimary
        case .onDim: .mediumSecondary
        }
    }
}

#Preview("새로고침 버튼") {
    YGErrorView(
        title: "서버와의 연결이 끊어졌어요",
        message: "다시 한 번 시도해 주세요",
        buttonTitle: "새로고침"
    ) {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.whiteFixed)
}

#Preview("버튼 2개") {
    YGErrorView(
        title: "사진 편집에 실패했어요",
        message: "다시 시도하거나 편집 없이 사용할 수 있어요",
        buttonTitle: "다시 시도",
        action: {},
        secondaryButtonTitle: "편집 없이 사용",
        secondaryAction: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.whiteFixed)
}

#Preview("버튼 없음") {
    YGErrorView(
        title: "서버와의 연결이 끊어졌어요",
        message: "앱을 다시 시작해 주세요"
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.whiteFixed)
}
