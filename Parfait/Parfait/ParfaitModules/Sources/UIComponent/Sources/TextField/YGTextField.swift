//
//  YGTextField.swift
//  ParfaitModules
//
//  Created by Enes on 7/9/26.
//

import SwiftUI

/// 파르페 공용 텍스트필드.
/// 상태(Empty/default/active/invalid)는 텍스트·포커스·errorMessage 로부터 파생된다.
public struct YGTextField: View {
    @Binding private var text: String
    private let placeholder: String
    private let maxLength: Int
    private let errorMessage: String?

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        maxLength: Int,
        errorMessage: String? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.errorMessage = errorMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                TextField(
                    "",
                    text: $text,
                    prompt: Text(placeholder).foregroundStyle(.gray300)
                )
                .suit(.body01Regular)
                .foregroundStyle(.gray900)
                .focused($isFocused)
                HStack(spacing: 0) {
                    if !text.isEmpty {
                        Text("\(text.count)/\(maxLength)")
                            .suit(errorMessage != nil ? .body02SemiBold : .body02Regular)
                            .foregroundStyle(errorMessage != nil ? .cherry600 : .gray400)
                    }
                    
                    if showsClearButton {
                        Button {
                            text = ""
                        } label: {
                            Image.icCloseRound
                                .frame(width: 44, height: 44)
                                .foregroundStyle(.gray300)
                        }
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 4)
            .frame(height: 48)
            .background(
                .whiteFixed.opacity(0.75),
                in: RoundedRectangle(cornerRadius: Radius.small)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.small)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .onChange(of: text) { _, newValue in
                if newValue.count > maxLength {
                    text = String(newValue.prefix(maxLength))
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .suit(.caption01Regular)
                    .foregroundStyle(.cherry600)
            }
        }
    }

    private var showsClearButton: Bool {
        !text.isEmpty && (isFocused || errorMessage != nil)
    }

    private var borderColor: Color {
        if errorMessage != nil { return .cherry600 }
        if isFocused { return .cherry200 }
        return .gray100
    }
}


#Preview {
    @Previewable @State var empty = ""
    @Previewable @State var filled = "파르페"
    @Previewable @State var invalid = "잘못된 닉네임!"

    VStack(spacing: 24) {
        YGTextField(
            text: $empty,
            placeholder: "닉네임을 입력해주세요",
            maxLength: 30
        )

        YGTextField(
            text: $filled,
            placeholder: "닉네임을 입력해주세요",
            maxLength: 10
        )

        YGTextField(
            text: $invalid,
            placeholder: "닉네임을 입력해주세요",
            maxLength: 10,
            errorMessage: "사용할 수 없는 닉네임입니다"
        )

        YGTitledTextField(
            title: "닉네임",
            text: $filled,
            placeholder: "닉네임을 입력해주세요",
            maxLength: 10
        )
    }
    .padding(20)
    .background(.gray50)
}
