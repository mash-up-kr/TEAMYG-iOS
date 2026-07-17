//
//  YGActionItem.swift
//  UIComponent
//
//  Created by 신상우 on 7/15/26.
//

import SwiftUI

/// 파르페 액션 아이템 컴포넌트.
///
/// Figma `Action-Item` 컴포넌트셋. 탭 가능한 텍스트 리스트 행으로,
/// 설정·메뉴 항목(예: "그룹 나가기")에 사용한다. 상태는 Default / Pressed 만 (Disabled 미지원).
public struct YGActionItem: View {
    private let title: String
    private let action: () -> Void

    public init(
        _ title: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(YGActionItemStyle())
    }
}

private struct YGActionItemStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .suit(.body02Regular)
            .lineLimit(1)
            .foregroundStyle(configuration.isPressed ? Color.gray700 : Color.gray500)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .padding5)
            .padding(.horizontal, .padding6)
            .contentShape(.rect)
    }
}

#Preview {
    VStack(spacing: 0) {
        YGActionItem("그룹 나가기") {}
        YGActionItem("그룹 삭제") {}
    }
}
