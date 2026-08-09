//
//  YGAlert.swift
//  UIComponent
//
//  Created by 신상우 on 7/17/26.
//

import SwiftUI

/// 파르페 알림 배너(Alert) 컴포넌트.
///
/// 반투명 검정 바에 타이틀·서브 텍스트 2줄과 우측 액션 칩(선택)을 얹는다.
/// Figma `Alert` — 칩 포함(728-4573) / 칩 없음(1023-2935, 칩 hidden).
///
/// 화면 상단 토스트로 띄울 때는 뷰를 직접 배치하지 말고
/// ``SwiftUICore/View/ygAlert(isPresented:content:)`` 를 사용한다
/// (위에서 내려와 노출, 위로 스와이프 or 2.5초 경과 시 닫힘 — Figma 805-4997).
public struct YGAlert: View {
    /// 우측 액션 칩 — Figma `Button-Chip-Right` 인스턴스, `YGChip`(trailing) 재사용.
    public struct Action {
        let title: String
        let handler: () -> Void

        public init(_ title: String, handler: @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    private let title: String
    private let subtitle: String
    private let titleColor: Color
    private let action: Action?

    /// - Parameter titleColor: 타이틀(닉네임) 색.
    ///   정책상 유저 Nametag 타입 색으로 강제 매핑된다(#33) → 호출부에서 주입.
    ///   기본값은 Figma 컴포넌트 스펙(`cherry200`).
    public init(
        title: String,
        subtitle: String,
        titleColor: Color = .cherry200,
        action: Action? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleColor = titleColor
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: .gap2) {
                Text(title)
                    .suit(.body02SemiBold)
                    .foregroundStyle(titleColor)
                Text(subtitle)
                    .suit(.body02Regular)
                    .foregroundStyle(.white75)
            }
            .lineLimit(1)
            .padding(.vertical, .padding5)

            Spacer(minLength: .gap5)

            if let action {
                YGChip(action.title, icon: .icCaretRight, placement: .trailing, action: action.handler)
            }
        }
        .padding(.horizontal, .padding7)
        .background(.black75)
    }
}

#Preview("프레젠테이션") {
    @Previewable @State var isPresented = false

    ZStack {
        Color.gray200.ignoresSafeArea()
        Button("알림 표시") { isPresented = true }
    }
    .ygTopBar(.default, onLeadingTap: {}, onNewGroupTap: {})
    .ygAlert(isPresented: $isPresented) {
        YGAlert(title: "Username", subtitle: "Action", action: .init("Text") {})
    }
}

#Preview("변형") {
    ZStack {
        Color.gray200.ignoresSafeArea()

        VStack(spacing: .gap5) {
            YGAlert(title: "Username", subtitle: "Action", action: .init("Text") {})
            YGAlert(title: "Username", subtitle: "Action")
        }
    }
}
