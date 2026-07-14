//
//  YGTabDemoView.swift
//  UIComponentDemo
//
//  Created by 신상우 on 7/14/26.
//

import SwiftUI
import UIComponent

/// YGTab 인터랙티브 데모.
/// Parfait / Edit 세그먼트를 전환하며 선택 강조·슬라이드 애니메이션을 확인한다.
struct YGTabDemoView: View {
    @State private var mode: YGTab.Mode = .parfait

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("현재 선택: \(mode.title)")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    Text("기본 배경(흰색)")
                        .font(.subheadline)
                        .foregroundStyle(.gray400)
                    YGTab(selection: $mode)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("컬러 배경 위 (반투명 트랙 확인용)")
                        .font(.subheadline)
                        .foregroundStyle(.gray400)
                    YGTab(selection: $mode)
                        .padding(20)
                        .background(.orange, in: .rect(cornerRadius: 16))
                }
            }
            .padding(20)
        }
        .navigationTitle("YGTab")
    }
}

#Preview {
    NavigationStack {
        YGTabDemoView()
    }
}
