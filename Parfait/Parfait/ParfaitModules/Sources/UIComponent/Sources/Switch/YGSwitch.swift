//
//  YGSwitch.swift
//  UIComponent
//
//  Created by 김남수 on 11/16/26.
//

import SwiftUI

/// 파르페 스위치 컴포넌트 (Figma `Switch` 6684-824).
///
/// 상태는 On / Off / Disabled 세 가지. Disabled 는 `.disabled(_:)` 로 전달한다.
public struct YGSwitch: View {
    @Binding private var isOn: Bool

    public init(isOn: Binding<Bool>) {
        _isOn = isOn
    }

    public var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(YGSwitchStyle())
    }
}

private struct YGSwitchStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Rectangle()
            .fill(isEnabled ? Color.whiteFixed : .gray50)
            .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                Rectangle()
                    .fill(knobColor(isOn: configuration.isOn))
                    .frame(width: 24, height: 24)
                    .padding(.padding2)
            }
            .overlay {
                Rectangle()
                    .strokeBorder(isEnabled && configuration.isOn ? Color.cherry200 : .gray200, lineWidth: 1)
            }
            .frame(width: 60, height: 32)
            .animation(.snappy(duration: 0.2), value: configuration.isOn)
            .contentShape(.rect)
            .onTapGesture {
                guard isEnabled else { return }
                configuration.isOn.toggle()
            }
            .accessibilityElement()
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(configuration.isOn ? "켬" : "끔")
    }

    private func knobColor(isOn: Bool) -> Color {
        guard isEnabled else { return .gray200 }
        return isOn ? .gray900 : .gray300
    }
}

#Preview {
    @Previewable @State var isOn = true

    VStack(spacing: .gap5) {
        YGSwitch(isOn: $isOn)
        YGSwitch(isOn: .constant(true))
            .disabled(true)
        YGSwitch(isOn: .constant(false))
            .disabled(true)
    }
    .padding()
    .background(.whiteFixed)
}
