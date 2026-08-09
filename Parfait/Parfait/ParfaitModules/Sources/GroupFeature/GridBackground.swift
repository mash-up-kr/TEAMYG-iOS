//
//  GridBackground.swift
//  GroupFeature
//
//  Created by 신상우 on 8/5/26.
//

import SwiftUI
import UIComponent

/// 파르페 뒤에 깔리는 모눈 배경.
///
/// **칸 크기는 기기와 무관하게 24pt 고정이고, 화면이 커지면 칸 수가 늘어난다.**
/// 이미지를 화면에 맞춰 늘리면 칸까지 같이 커지므로 벡터로 그린다 —
/// 시안 격자도 텍스처가 아니라 24pt 간격 직선이라 그대로 재현된다.
struct GridBackground: View {
    /// 칸 간격.
    private static let spacing: CGFloat = 24
    private static let lineWidth: CGFloat = 1
    /// 첫 선의 위치 — 시안 기준 세로선 x=19, 가로선 y=24 (화면 최상단부터).
    private static let firstLine = CGPoint(x: 19, y: 24)

    var body: some View {
        Canvas { context, size in
            var path = Path()

            var positionX = Self.firstLine.x
            while positionX <= size.width {
                path.move(to: CGPoint(x: positionX, y: 0))
                path.addLine(to: CGPoint(x: positionX, y: size.height))
                positionX += Self.spacing
            }

            var positionY = Self.firstLine.y
            while positionY <= size.height {
                path.move(to: CGPoint(x: 0, y: positionY))
                path.addLine(to: CGPoint(x: size.width, y: positionY))
                positionY += Self.spacing
            }

            context.stroke(path, with: .color(.soda500.opacity(0.15)), lineWidth: Self.lineWidth)
        }
        .background(.whiteFixed)
        .ignoresSafeArea()
    }
}

#Preview {
    GridBackground()
}
