//
//  MemberCountPicker.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import SwiftUI
import UIComponent

/// 그룹 인원 선택 그리드 (A-005). 6열 × 2행으로 1~12 를 늘어놓고 하나만 고른다.
///
/// ponytail: Figma `Button-Input-Number` 는 디자인 시스템 컴포넌트라 원래 `UIComponent` 자리다.
///           지금은 이 화면에서만 쓰여 여기 두고, 다른 화면에도 나오면 `YGNumberButton` 으로 승격할 것.
struct MemberCountPicker: View {
    let range: ClosedRange<Int>
    let selection: Int?
    let onSelect: (Int) -> Void

    private static let columnCount = 6
    private static let cellHeight: CGFloat = 50
    private static let columnGap: CGFloat = 7
    private static let rowGap: CGFloat = 6

    var body: some View {
        // 셀 폭은 화면 폭에 맞춰 늘어난다 — 디자인 375pt 기준으로는 정확히 50이 된다.
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: Self.columnGap),
                count: Self.columnCount
            ),
            spacing: Self.rowGap
        ) {
            ForEach(Array(range), id: \.self) { count in
                cell(count)
            }
        }
    }

    private func cell(_ count: Int) -> some View {
        let isSelected = selection == count
        return Button {
            onSelect(count)
        } label: {
            Text("\(count)")
                .suit(.body01Regular)
                .foregroundStyle(isSelected ? Color.whiteFixed : .gray900)
                .frame(maxWidth: .infinity)
                .frame(height: Self.cellHeight)
                .background(isSelected ? Color.gray900 : .whiteFixed, in: .rect)
                .overlay {
                    Rectangle()
                        .strokeBorder(isSelected ? Color.gray900 : .gray100, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    @Previewable @State var selection: Int? = 9

    MemberCountPicker(range: 1...12, selection: selection) { count in
        selection = selection == count ? nil : count
    }
    .padding(.horizontal, .padding7)
    .frame(maxHeight: .infinity)
    .background(.gray50)
}
