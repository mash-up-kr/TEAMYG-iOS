//
//  ToppingHistoryBar.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

import SwiftUI
import UIComponent

/// C-104(마스크)·C-105(테두리) 상단의 undo/redo 바.
///
/// Figma 는 두 화면이 같은 컴포넌트(`Button-Edit-Action`)를 쓴다 — 실측값으로 확인했다
/// (C-104 `1830:20423`, C-105 `1179:6921`). 터치 42 / 원 38 / 아이콘 22,
/// 활성 `black50`+`whiteFixed`, 비활성 `black5`+`gray200`, 테두리 `white25` 1.5pt.
struct ToppingHistoryBar: View {
    private static let touchLength: CGFloat = 42
    private static let circleLength: CGFloat = 38
    private static let iconLength: CGFloat = 22
    private static let borderWidth: CGFloat = 1.5
    /// Figma 상 두 버튼의 x 간격이 44pt, 버튼 폭이 42pt다.
    private static let buttonSpacing: CGFloat = .gap1

    let canUndo: Bool
    let canRedo: Bool
    let onUndoTap: () -> Void
    let onRedoTap: () -> Void

    var body: some View {
        HStack(spacing: Self.buttonSpacing) {
            button(.icArrowLeft, isEnabled: canUndo, action: onUndoTap)
            button(.icArrowRight, isEnabled: canRedo, action: onRedoTap)
            Spacer(minLength: 0)
        }
    }

    private func button(_ icon: Image, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon
                .renderingMode(.template)
                .resizable()
                .frame(width: Self.iconLength, height: Self.iconLength)
                .foregroundStyle(isEnabled ? Color.whiteFixed : .gray200)
                .frame(width: Self.circleLength, height: Self.circleLength)
                .background(isEnabled ? Color.black50 : .black5, in: .circle)
                .overlay {
                    Circle()
                        .strokeBorder(.white25, lineWidth: Self.borderWidth)
                }
                .frame(width: Self.touchLength, height: Self.touchLength)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
