//
//  YGUserChipDemoView.swift
//  UIComponentDemo
//
//  Created by 신상우 on 7/15/26.
//

import SwiftUI
import UIComponent

/// YGUserChip 데모.
/// 본인 여부(isSelf)와 Nametag 타입을 바꿔가며 확인한다.
struct YGUserChipDemoView: View {
    @State private var nickname = "아니야나그런데기니야기니라니까"
    @State private var typeRawValue = 4

    private var type: YGNametagChip.NametagType {
        YGNametagChip.NametagType(rawValue: typeRawValue) ?? .type1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                TextField("닉네임", text: $nickname)
                    .textFieldStyle(.roundedBorder)

                Stepper("Nametag Type: \(typeRawValue)", value: $typeRawValue, in: 1...12)
                    .font(.subheadline)

                section(title: "Self = true (본인)", isSelf: true)
                section(title: "Self = false", isSelf: false)
            }
            .padding(20)
        }
        .navigationTitle("YGUserChip")
    }

    private func section(title: String, isSelf: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.gray400)
            YGUserChip(nickname: nickname, type: type, isSelf: isSelf)
        }
    }
}

#Preview {
    NavigationStack {
        YGUserChipDemoView()
    }
}
