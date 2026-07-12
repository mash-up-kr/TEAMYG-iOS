//
//  YGTextFieldDemoView.swift
//  UIComponentDemo
//
//  Created by Enes on 7/9/26.
//

import SwiftUI
import UIComponent

/// YGTextField 인터랙티브 데모.
/// Empty/default/active 는 직접 입력·포커스로, invalid 는 토글로 확인한다.
struct YGTextFieldDemoView: View {
    @State private var plainText = ""
    @State private var titledText = ""
    @State private var forcesError = false

    private var errorMessage: String? {
        forcesError ? "사용할 수 없는 닉네임입니다" : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                YGTextField(
                    text: $plainText,
                    placeholder: "닉네임을 입력해주세요",
                    maxLength: 10,
                    errorMessage: errorMessage
                )

                YGTitledTextField(
                    title: "닉네임",
                    text: $titledText,
                    placeholder: "닉네임을 입력해주세요",
                    maxLength: 10,
                    errorMessage: errorMessage
                )

                Toggle("invalid 상태 강제", isOn: $forcesError)
            }
            .padding(20)
        }
        .background(.gray50)
        .navigationTitle("YGTextField")
    }
}

#Preview {
    NavigationStack {
        YGTextFieldDemoView()
    }
}
