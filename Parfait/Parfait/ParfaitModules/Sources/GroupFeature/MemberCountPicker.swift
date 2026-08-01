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
    /// Figma `Button-Input-Number` 는 50×50 고정이라 화면 폭에 따라 늘리지 않는다.
    private static let cellSize: CGFloat = 50
    /// 열 사이 최소 간격. 디자인 375pt 기준으로 6칸(300) + 간격 5개(35) = 335 로 딱 맞고,
    /// 더 넓은 화면에서 남는 폭은 `Spacer` 가 간격에 고르게 나눠 갖는다 —
    /// 셀을 늘리면 정사각형이 깨지고, 한쪽에 몰아 두면 위 입력 필드와 좌우가 어긋난다.
    private static let columnGap: CGFloat = 7
    private static let rowGap: CGFloat = 6

    var body: some View {
        VStack(spacing: Self.rowGap) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { count in
                        cell(count)
                        if count != row.last {
                            Spacer(minLength: Self.columnGap)
                        }
                    }
                }
                // 6칸을 채운 행은 `Spacer` 가 이미 폭을 채운다. 못 채운 행만 왼쪽으로 붙인다.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// 6칸씩 끊은 행들. 마지막 행이 6칸을 못 채우면 남는 자리는 비워 둔다(현재 1...12 는 딱 2행).
    private var rows: [[Int]] {
        let counts = Array(range)
        return stride(from: 0, to: counts.count, by: Self.columnCount).map { start in
            Array(counts[start..<min(start + Self.columnCount, counts.count)])
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
                .frame(width: Self.cellSize, height: Self.cellSize)
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
