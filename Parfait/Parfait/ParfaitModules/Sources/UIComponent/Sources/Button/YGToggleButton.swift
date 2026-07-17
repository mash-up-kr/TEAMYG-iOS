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
/// 상태는 `Binding<Bool>` 으로 소유한다. 탭하면 내부에서 값을 토글하므로 호출자가 상태 변경
/// 코드를 쓸 필요가 없다. 토글에 부수효과가 필요하면 `action` 을 넘긴다(옵셔널).
///
/// ```swift
/// YGToggleButton("Edit", isSelected: $isOn)                 // 상태만 토글
/// YGToggleButton("Edit", isSelected: $isOn) { log("tap") }  // 토글 + 부수효과
/// ```
///
/// - Selected: 배경 `whiteFixed`, 텍스트 `gray900`, `body01SemiBold`
/// - Default:  배경 투명,          텍스트 `black50`, `body01Regular`
public struct YGToggleButton: View {
    private let title: String
    private let icon: Image?
    private let isSelected: Binding<Bool>
    private let action: (() -> Void)?

    public init(
        _ title: String,
        icon: Image? = nil,
        isSelected: Binding<Bool>,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    private var isOn: Bool { isSelected.wrappedValue }

    public var body: some View {
        Button {
            isSelected.wrappedValue.toggle()
            action?()
        } label: {
            HStack(spacing: .gap2) {
                if let icon {
                    icon
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                Text(title)
                    .suit(isOn ? .body01SemiBold : .body01Regular)
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? Color.gray900 : Color.black50)
        }
        .buttonStyle(YGToggleButtonStyle(isSelected: isOn, hasIcon: icon != nil))
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
