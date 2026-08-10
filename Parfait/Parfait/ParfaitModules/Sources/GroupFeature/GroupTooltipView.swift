//
//  GroupTooltipView.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import SwiftUI
import UIComponent

/// 그룹이 0건일 때 "그룹 추가하기" 버튼을 가리키는 온보딩 툴팁 (G-001-Empty).
///
/// 최초 1회 플래그를 두지 않는다 — 0건이면 진입할 때마다 다시 뜬다. 닫기는 툴팁 밖 탭.
struct GroupTooltipView: View {
    /// 말풍선 오른쪽 끝에서 꼬리 중앙까지 — 상단 바의 그룹 추가 칩을 가리키는 자리.
    private static let pointerInsetFromTrailing: CGFloat = 54.35
    private static let pointerSize = CGSize(width: 17.1, height: 16)
    private static let bodyHeight: CGFloat = 73
    /// 좌우 여백이 다르다 — 시안 기준 좌 31 / 우 20 (375 폭에서 말풍선 324).
    private static let leadingInset: CGFloat = 31
    private static let trailingInset: CGFloat = 20

    var body: some View {
        message
            .frame(maxWidth: .infinity)
            .frame(height: Self.bodyHeight)
            .padding(.top, Self.pointerSize.height)
            .background {
                TooltipBubbleShape(
                    pointerSize: Self.pointerSize,
                    pointerInsetFromTrailing: Self.pointerInsetFromTrailing
                )
                .fill(.whiteFixed)
                .stroke(.melon500, lineWidth: 1.25)
            }
            .padding(.leading, Self.leadingInset)
            .padding(.trailing, Self.trailingInset)
    }

    private var message: some View {
        VStack(spacing: 0) {
            line {
                Text("여기를 눌러 ")
                emphasis("새 그룹")
                Text("을 만들거나,")
            }
            line {
                Text("친구에게 받은 초대코드로 ")
                emphasis("그룹에 참여")
                Text("해 보세요.")
            }
        }
        .foregroundStyle(.blackFixed)
    }

    private func line(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 0) { content() }
            .suit(.body02Regular)
    }

    private func emphasis(_ text: String) -> some View {
        Text(text)
            .suit(.body02Bold)
            .foregroundStyle(.melon500)
    }
}

/// 위쪽 오른편에 삼각 꼬리가 달린 말풍선. 몸통과 꼬리를 한 경로로 그려 외곽선이 이어진다.
private struct TooltipBubbleShape: Shape {
    let pointerSize: CGSize
    let pointerInsetFromTrailing: CGFloat

    func path(in rect: CGRect) -> Path {
        let bodyTop = rect.minY + pointerSize.height
        let pointerCenterX = rect.maxX - pointerInsetFromTrailing
        let pointerHalfWidth = pointerSize.width / 2

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: bodyTop))
        path.addLine(to: CGPoint(x: pointerCenterX - pointerHalfWidth, y: bodyTop))
        path.addLine(to: CGPoint(x: pointerCenterX, y: rect.minY))
        path.addLine(to: CGPoint(x: pointerCenterX + pointerHalfWidth, y: bodyTop))
        path.addLine(to: CGPoint(x: rect.maxX, y: bodyTop))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    GroupTooltipView()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.whiteFixed)
}
