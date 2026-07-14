//
//  YGToggleButton.swift
//  UIComponent
//
//  Created by 신상우 on 7/14/26.
//

import SwiftUI

/// 파르페 Toggle 버튼 컴포넌트.
///
/// Figma `Button-Toggle` — 선택(Selected)/비선택(Default) 두 상태만 갖는 알약(capsule) 버튼.
/// 아이콘은 선택적이다: 넘기면 텍스트 왼쪽에 붙고(Figma `Type=Parfait`),
/// 생략하면 텍스트만 표시한다(Figma `Type=Edit`). Disabled 상태는 없다.
///
/// 두 가지 사용법:
/// - **독립 토글**: `isSelected` 에 `Binding<Bool>` 을 넘기면 탭할 때 값이 자동으로 전환된다.
/// - **제어형**: 단일 선택 그룹처럼 탭 동작을 직접 정해야 하면 `isSelected: Bool` + `action` 을 쓴다.
///
/// 어느 쪽이든 상태의 원본(source of truth)은 바깥에 있다. 내부 `@State` 를 두지 않으므로
/// 외부 값이 바뀌면 항상 그대로 반영된다.
///
/// - Selected: 배경 `whiteFixed`, 텍스트 `gray900`, `body01SemiBold`
/// - Default:  배경 투명,          텍스트 `black50`, `body01Regular`
public struct YGToggleButton: View {
    private let title: String
    private let icon: Image?
    private let isSelected: Bool
    private let action: () -> Void

    /// 독립 토글. 탭하면 `isSelected` 값이 자동으로 on/off 전환된다.
    public init(
        _ title: String,
        icon: Image? = nil,
        isSelected: Binding<Bool>
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected.wrappedValue
        self.action = { isSelected.wrappedValue.toggle() }
    }

    /// 제어형. 탭 동작(`action`)을 호출자가 정의한다 (예: 단일 선택 그룹).
    public init(
        _ title: String,
        icon: Image? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: .gap2) {
                if let icon {
                    icon
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                Text(title)
                    .suit(isSelected ? .body01SemiBold : .body01Regular)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.gray900 : Color.black50)
        }
        .buttonStyle(YGToggleButtonStyle(isSelected: isSelected, hasIcon: icon != nil))
    }
}

/// 배경(capsule)·여백만 담당. 색·폰트는 상태에 따라 라벨 쪽에서 적용한다.
private struct YGToggleButtonStyle: ButtonStyle {
    let isSelected: Bool
    let hasIcon: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, .padding3)
            // 아이콘 쪽 8(padding3) · 텍스트 쪽 12(padding5)
            .padding(.leading, hasIcon ? .padding3 : .padding5)
            .padding(.trailing, .padding5)
            .background(isSelected ? Color.whiteFixed : .clear, in: .capsule)
            // Figma 에 pressed 상태는 없지만, 다른 YG 버튼들과 맞춰 탭 피드백을 준다.
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

#Preview {
    @Previewable @State var parfaitSelected = true
    @Previewable @State var editSelected = false

    VStack(alignment: .leading, spacing: .gap5) {
        YGToggleButton("Parfait", icon: .icPlus, isSelected: $parfaitSelected)
        YGToggleButton("Edit", isSelected: $editSelected)
    }
    .padding(.padding8)
    .background(.gray200)
}
