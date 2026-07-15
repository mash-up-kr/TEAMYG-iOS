//
//  InviteCodeInputField.swift
//  GroupFeature
//
//  Created by 김남수 on 7/15/26.
//

import SwiftUI
import UIComponent

/// 초대코드 6칸 입력 UI.
/// 숨은 단일 TextField 가 실제 입력을 받고, 6개 표시 셀은 그 문자열에서 파생 렌더링한다
/// (자동 칸 이동·붙여넣기가 텍스트필드 기본 동작으로 해결됨).
struct InviteCodeInputField: View {
    @Binding var inviteCode: String
    let isFailed: Bool
    let onTap: () -> Void

    @FocusState private var isFocused: Bool

    private static let inviteCodeLength = 6
    private let cellWidth: CGFloat = 49
    private let cellHeight: CGFloat = 56
    private let cellSpacing: CGFloat = 8

    var body: some View {
        let characters = Array(inviteCode)
        let activeIndex = inviteCode.count < Self.inviteCodeLength ? inviteCode.count : nil

        ZStack {
            HStack(spacing: cellSpacing) {
                ForEach(0..<Self.inviteCodeLength, id: \.self) { index in
                    cell(
                        character: index < characters.count ? String(characters[index]) : "",
                        isActive: isFocused && activeIndex == index
                    )
                }
            }

            // ponytail: 앱 전용 초대코드 포맷 확정 시 클립보드 자동 감지 추가 (현재는 시스템 붙여넣기로 충분)
            TextField("", text: $inviteCode)
                .keyboardType(.asciiCapable)
                .autocorrectionDisabled()
                .focused($isFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(width: fieldWidth, height: cellHeight)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        onTap()
                        isFocused = true
                    }
                )
        }
    }

    private var fieldWidth: CGFloat {
        cellWidth * CGFloat(Self.inviteCodeLength) + cellSpacing * CGFloat(Self.inviteCodeLength - 1)
    }

    private func cell(character: String, isActive: Bool) -> some View {
        VStack(spacing: .gap2) {
            Spacer()
            Text(character)
                .suit(.title02SemiBold)
                .foregroundStyle(.gray900)
            Rectangle()
                .fill(underlineColor(isActive: isActive))
                .frame(height: 2)
        }
        .frame(width: cellWidth, height: cellHeight)
    }

    private func underlineColor(isActive: Bool) -> Color {
        if isFailed { return .cherry600 }
        if isActive { return .cherry200 }
        return .gray100
    }
}

#Preview {
    @Previewable @State var inviteCode = ""
    @Previewable @State var isFailed = false

    VStack(spacing: 24) {
        InviteCodeInputField(inviteCode: $inviteCode, isFailed: isFailed, onTap: {})

        Toggle("에러 상태", isOn: $isFailed)
    }
    .padding(20)
}
