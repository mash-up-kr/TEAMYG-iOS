//
//  YGPopupModifier.swift
//  UIComponent
//
//  Created by 김남수 on 7/17/26.
//

import SwiftUI

/// 화면 위에 YGPopup 을 띄우는 모디파이어. 버튼 탭 시 팝업을 닫은 뒤 액션을 실행한다.
struct YGPopupModifier: ViewModifier {
    @Binding var isPresented: Bool
    let icon: Image
    let title: String
    let description: String
    let secondaryTitle: String
    let primaryTitle: String
    let secondaryAction: () -> Void
    let primaryAction: () -> Void

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                YGPopup(
                    icon: icon,
                    title: title,
                    description: description,
                    secondaryTitle: secondaryTitle,
                    primaryTitle: primaryTitle,
                    secondaryAction: {
                        isPresented = false
                        secondaryAction()
                    },
                    primaryAction: {
                        isPresented = false
                        primaryAction()
                    }
                )
            }
        }
    }
}

public extension View {
    /// 화면 위에 YGPopup 을 띄운다. 버튼 탭 시 팝업을 닫은 뒤 액션을 실행한다.
    /// 딤이 전체 화면을 덮도록 화면 루트 뷰에 붙일 것.
    func ygPopup(
        isPresented: Binding<Bool>,
        icon: Image = .icWarningRound,
        title: String,
        description: String,
        secondaryTitle: String,
        primaryTitle: String,
        secondaryAction: @escaping () -> Void = {},
        primaryAction: @escaping () -> Void
    ) -> some View {
        modifier(
            YGPopupModifier(
                isPresented: isPresented,
                icon: icon,
                title: title,
                description: description,
                secondaryTitle: secondaryTitle,
                primaryTitle: primaryTitle,
                secondaryAction: secondaryAction,
                primaryAction: primaryAction
            )
        )
    }
}

#Preview {
    @Previewable @State var showsPopup = true
    ZStack {
        Color.orange.ignoresSafeArea() // 딤 확인용
        Button("팝업 열기") { showsPopup = true }
    }
    .ygPopup(
        isPresented: $showsPopup,
        title: "그룹을 나가시겠어요?",
        description: "지금까지 쌓은 체리가 모두 사라져요.\n그래도 나가시겠어요?",
        secondaryTitle: "취소",
        primaryTitle: "나가기",
        primaryAction: {}
    )
}
