//
//  YGNametagChipDemoView.swift
//  UIComponentDemo
//
//  Created by 신상우 on 7/15/26.
//

import SwiftUI
import UIComponent

/// YGNametagChip 데모.
/// 닉네임을 바꿔가며 12개 타입 × medium/large 와 오버플로(+N) 변형을 확인한다.
/// 각 행 오른쪽의 색 견본은 토스트 닉네임·Grouptag Timestamp 에 매핑되는 강조색(accentColor).
struct YGNametagChipDemoView: View {
    @State private var nickname = "김남수"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                TextField("닉네임", text: $nickname)
                    .textFieldStyle(.roundedBorder)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    ForEach(YGNametagChip.NametagType.allCases, id: \.rawValue) { type in
                        GridRow {
                            Text("Type \(type.rawValue)")
                                .font(.subheadline)
                                .foregroundStyle(.gray400)
                            YGNametagChip(nickname: nickname, type: type, size: .medium)
                            YGNametagChip(nickname: nickname, type: type, size: .large)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(type.accentColor)
                                .stroke(.gray200, lineWidth: 0.5)
                                .frame(width: 24, height: 24)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("오버플로 (+N)")
                        .font(.subheadline)
                        .foregroundStyle(.gray400)
                    HStack(spacing: 12) {
                        YGNametagChip(overflowCount: 7)
                        YGNametagChip(overflowCount: 12)
                        YGNametagChip(overflowCount: 99)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("YGNametagChip")
    }
}

#Preview {
    NavigationStack {
        YGNametagChipDemoView()
    }
}
