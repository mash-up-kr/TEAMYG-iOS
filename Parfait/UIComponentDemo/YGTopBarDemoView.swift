//
//  YGTopBarDemoView.swift
//  UIComponentDemo
//
//  Created by 신상우 on 7/13/26.
//

import SwiftUI
import UIComponent

/// YGTopBar 데모.
/// 4가지 Status(empty/default/back/detail)를 나열하고, 버튼 탭은 하단에 마지막 액션으로 표시한다.
struct YGTopBarDemoView: View {
    @State private var lastAction = "버튼을 탭해보세요"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            labeled("empty") {
                YGTopBar(.empty) { lastAction = "empty · 사이드메뉴" }
            }
            labeled("default") {
                YGTopBar(.default) {
                    lastAction = "default · 사이드메뉴"
                } onNewGroupTap: {
                    lastAction = "default · 새 그룹"
                }
            }
            labeled("back") {
                YGTopBar(.back) { lastAction = "back · 뒤로가기" }
            }
            labeled("detail") {
                YGTopBar(.detail(title: "그룹이름")) { lastAction = "detail · 뒤로가기" }
            }

            Text(lastAction)
                .suit(.body02Regular)
                .foregroundStyle(.gray600)
                .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.gray50)
        .navigationTitle("YGTopBar")
    }

    private func labeled(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .suit(.caption01Medium)
                .foregroundStyle(.gray400)
                .padding(.horizontal, 20)
            content()
        }
    }
}

#Preview {
    NavigationStack {
        YGTopBarDemoView()
    }
}
