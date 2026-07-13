//
//  YGIconButtonDemoView.swift
//  UIComponentDemo
//
//  Created by 김남수 on 7/12/26.
//

import SwiftUI
import UIComponent

/// YGIconButton 인터랙티브 데모.
/// size(small·large) × 상태(default·disabled)를 나란히 확인한다. 탭하면 카운트가 오른다.
struct YGIconButtonDemoView: View {
    @State private var tapCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("탭 횟수: \(tapCount)")
                    .font(.headline)

                section(title: "small (아이콘 24 · 터치 44)", size: .small)
                section(title: "large (아이콘 32 · 터치 48)", size: .large)
            }
            .padding(20)
        }
        .navigationTitle("YGIconButton")
    }

    private func section(title: String, size: YGIconButton.Size) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.gray400)

            HStack(spacing: 20) {
                YGIconButton(.icClose, size: size) { tapCount += 1 }
                YGIconButton(.icHamburger, size: size) { tapCount += 1 }

                YGIconButton(.icHamburger, size: size) {}
                    .disabled(true)
                Text("disabled")
                    .font(.caption)
                    .foregroundStyle(.gray300)
            }
        }
    }
}

#Preview {
    NavigationStack {
        YGIconButtonDemoView()
    }
}
