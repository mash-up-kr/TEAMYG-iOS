//
//  YGDangerZone.swift
//  UIComponent
//
//  Created by 김남수 on 7/28/26.
//

import SwiftUI

public struct YGDangerZone<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                if let first = subviews.first {
                    first
                    ForEach(subviews.dropFirst()) { subview in
                        DashedHorizontalLine()
                            .stroke(Color.gray100, style: .ygDashed)
                            .frame(height: 1)
                        subview
                    }
                }
            }
        }
        .padding(.vertical, .padding2)
        .overlay {
            Rectangle()
                .strokeBorder(Color.gray100, style: .ygDashed)
        }
    }
}

private extension StrokeStyle {
    static let ygDashed = StrokeStyle(lineWidth: 1, dash: [4, 4])
}

/// 점선 가로줄. `Divider` 는 dash 를 지원하지 않아 직접 그린다.
private struct DashedHorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

#Preview {
    YGDangerZone {
        YGActionItem("로그아웃") {}
        YGActionItem("서비스 탈퇴하기") {}
    }
    .padding()
}
