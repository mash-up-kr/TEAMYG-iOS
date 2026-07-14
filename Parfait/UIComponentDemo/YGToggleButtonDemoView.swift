//
//  YGToggleButtonDemoView.swift
//  UIComponentDemo
//
//  Created by 신상우 on 7/14/26.
//

import SwiftUI
import UIComponent

/// YGToggleButton 인터랙티브 데모.
/// 개별 토글 · 단일 선택 그룹 · 상태 비교를 확인한다.
/// Selected 배경(whiteFixed)이 흰 배경에선 안 보여서, 확인용으로 회색 카드 위에 올린다.
struct YGToggleButtonDemoView: View {
    @State private var parfaitSelected = true
    @State private var editSelected = false
    @State private var groupSelection = 0

    private let groupTitles = ["Day", "Week", "Month"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                section("개별 토글 (Binding — 탭하면 자동 전환)") {
                    YGToggleButton("Parfait", icon: .icPlus, isSelected: $parfaitSelected)
                    YGToggleButton("Edit", isSelected: $editSelected)
                }

                section("단일 선택 그룹 (하나만 Selected)") {
                    HStack(spacing: 8) {
                        ForEach(Array(groupTitles.enumerated()), id: \.offset) { index, title in
                            YGToggleButton(title, isSelected: groupSelection == index) {
                                groupSelection = index
                            }
                        }
                    }
                }

                section("상태 비교") {
                    row("Parfait", icon: .icPlus)
                    row("Edit", icon: nil)
                }
            }
            .padding(20)
        }
        .navigationTitle("YGToggleButton")
    }

    /// 회색 카드 배경으로 Selected(whiteFixed) 도 눈에 보이게 감싼다.
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.gray400)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.gray200, in: .rect(cornerRadius: 12))
        }
    }

    private func row(_ title: String, icon: Image?) -> some View {
        HStack(spacing: 12) {
            YGToggleButton(title, icon: icon, isSelected: true) {}
            YGToggleButton(title, icon: icon, isSelected: false) {}
        }
    }
}

#Preview {
    NavigationStack {
        YGToggleButtonDemoView()
    }
}
