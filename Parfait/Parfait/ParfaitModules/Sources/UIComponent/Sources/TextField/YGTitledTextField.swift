//
//  YGTitledTextField.swift
//  ParfaitModules
//
//  Created by Enes on 7/9/26.
//

import SwiftUI

/// 상단 타이틀이 붙은 텍스트필드.
public struct YGTitledTextField: View {
    private let title: String
    @Binding private var text: String
    private let placeholder: String
    private let maxLength: Int
    private let errorMessage: String?

    public init(
        title: String,
        text: Binding<String>,
        placeholder: String,
        maxLength: Int,
        errorMessage: String? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.errorMessage = errorMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .suit(.body02Regular)
                .foregroundStyle(.gray400)

            YGTextField(
                text: $text,
                placeholder: placeholder,
                maxLength: maxLength,
                errorMessage: errorMessage
            )
        }
    }
}
