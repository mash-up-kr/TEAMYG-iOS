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
/// (자동 칸 이동이 텍스트필드 기본 동작으로 해결됨).
struct InviteCodeInputField: View {
    @Binding var inviteCode: String
    let isFailed: Bool
    /// 실패 상태의 필드를 탭했을 때 호출 — 정상 상태 탭에는 불리지 않는다.
    let onTapWhileFailed: () -> Void

    @FocusState private var isFocused: Bool

    private static let cellWidth: CGFloat = 49
    private static let cellHeight: CGFloat = 56
    private static let cellSpacing: CGFloat = 8

    /// 6칸 입력 UI 의 전체 너비 — 부모가 에러 메시지 정렬 폭을 맞출 때 참조.
    static var fieldWidth: CGFloat {
        cellWidth * CGFloat(InviteCodeStore.inviteCodeLength)
            + cellSpacing * CGFloat(InviteCodeStore.inviteCodeLength - 1)
    }

    var body: some View {
        let characters = Array(inviteCode)
        let activeIndex = inviteCode.count < InviteCodeStore.inviteCodeLength ? inviteCode.count : nil

        ZStack {
            HStack(spacing: Self.cellSpacing) {
                ForEach(0..<InviteCodeStore.inviteCodeLength, id: \.self) { index in
                    cell(
                        character: index < characters.count ? String(characters[index]) : "",
                        isActive: isFocused && activeIndex == index
                    )
                }
            }

            // 터치 차단으로 시스템 롱프레스 붙여넣기는 막힘 — 붙여넣기는
            // InviteCodeView 의 PasteButton("parfait <코드>" 형식)이 담당.
            // 허용 문자(대문자+숫자) 필터·대문자화는 Store 의 inviteCodeChanged 에서 처리.
            TextField("", text: $inviteCode)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(width: Self.fieldWidth, height: Self.cellHeight)
                .allowsHitTesting(false)

            // 터치는 전부 이 레이어가 받고 포커스만 넘긴다 — TextField 에 터치가
            // 닿지 않으므로 롱프레스/드래그해도 루페·선택 핸들·편집 메뉴가 뜨지 않는다.
            Color.clear
                .contentShape(Rectangle())
                .frame(width: Self.fieldWidth, height: Self.cellHeight)
                .onTapGesture {
                    if isFailed {
                        onTapWhileFailed()
                    }
                    isFocused = true
                }
        }
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
        .frame(width: Self.cellWidth, height: Self.cellHeight)
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
        InviteCodeInputField(inviteCode: $inviteCode, isFailed: isFailed, onTapWhileFailed: {})

        Toggle("에러 상태", isOn: $isFailed)
    }
    .padding(20)
}
