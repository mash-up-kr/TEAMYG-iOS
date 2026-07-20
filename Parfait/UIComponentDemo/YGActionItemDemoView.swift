//
//  YGActionItemDemoView.swift
//  UIComponentDemo
//
//  Created by 신상우 on 7/15/26.
//

import SwiftUI
import UIComponent

/// YGActionItem 인터랙티브 데모.
/// 탭하면 카운트가 오른다 (Pressed 색 변화는 누르는 동안 표시).
struct YGActionItemDemoView: View {
    @State private var tapCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("탭 횟수: \(tapCount)")
                    .font(.headline)

                VStack(spacing: 0) {
                    YGActionItem("그룹 나가기") { tapCount += 1 }
                    YGActionItem("그룹 삭제") { tapCount += 1 }
                }
            }
            .padding(20)
        }
        .navigationTitle("YGActionItem")
    }
}

#Preview {
    NavigationStack {
        YGActionItemDemoView()
    }
}
