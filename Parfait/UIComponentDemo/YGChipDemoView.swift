//
//  YGChipDemoView.swift
//  UIComponentDemo
//
//  Created by 신상우 on 7/14/26.
//

import SwiftUI
import UIComponent

/// YGChip 인터랙티브 데모.
/// placement(leading·trailing) 별로 나란히 확인한다. 탭하면 카운트가 오른다(눌림 상태는 누르는 동안 표시).
struct YGChipDemoView: View {
    @State private var tapCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("탭 횟수: \(tapCount)")
                    .font(.headline)

                section(title: "leading (아이콘 왼쪽 · Button-Chip-Left)", placement: .leading)
                section(title: "trailing (아이콘 오른쪽 · Button-Chip-Right)", placement: .trailing)
            }
            .padding(20)
        }
        .navigationTitle("YGChip")
    }

    private func section(title: String, placement: YGChip.IconPlacement) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.gray400)

            HStack(spacing: 12) {
                YGChip("새 그룹", icon: .icPlus, placement: placement) { tapCount += 1 }
                YGChip("전체", icon: .icPlus, placement: placement) { tapCount += 1 }
            }
        }
    }
}

#Preview {
    NavigationStack {
        YGChipDemoView()
    }
}
