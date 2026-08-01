//
//  ParfaitSceneView.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import GroupDomain
import SwiftUI
import UIComponent

/// 파르페(체리·크림·접시)와 그 위에 얹힌 토핑들.
///
/// `ParfaitLayout` 이 375pt 디자인 좌표로 계산한 자리를 화면 폭에 맞춰 확대해 그린다.
/// 체리는 맨 위, 접시는 맨 아래 고정이고 그 사이 크림만 그룹 수만큼 늘어난다.
struct ParfaitSceneView: View {
    let groups: [YGGroup]
    /// 화면 폭 / 디자인 폭.
    let scale: CGFloat
    let onToppingTap: (YGGroup) -> Void

    @Environment(\.isParfaitLayoutAnimationEnabled) private var isLayoutAnimationEnabled

    private var layout: ParfaitLayout { ParfaitLayout(groupCount: groups.count) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            parfait
            toppings
        }
        .frame(
            width: ParfaitLayout.designWidth * scale,
            height: layout.contentHeight * scale,
            alignment: .topLeading
        )
        // 그룹이 늘거나 빠지면 뒤 토핑이 한 칸씩 당겨지고 크림도 함께 자란다 — 그 이동을 이어서 보여준다.
        .animation(isLayoutAnimationEnabled ? .snappy : nil, value: groups)
    }

    /// 그리는 순서 = 아래에서 위로 쌓는 순서. 맨 아래 크림부터 깔아야 위 크림이 앞에 온다.
    private var parfait: some View {
        ZStack(alignment: .topLeading) {
            part(.parfaitCherry, in: layout.cherryFrame)

            ForEach(Array(layout.creamBodyFrames.enumerated().reversed()), id: \.offset) { _, frame in
                part(.parfaitCreamBody, in: frame)
            }

            part(.parfaitCreamTop, in: layout.creamTopFrame)
            part(.parfaitCup, in: layout.cupFrame)
        }
    }

    private var toppings: some View {
        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
            let frame = layout.toppingFrame(at: index)
            ToppingView(group: group, index: index, scale: scale) { onToppingTap(group) }
                .offset(x: frame.minX * scale, y: frame.minY * scale)
        }
    }

    private func part(_ image: Image, in frame: CGRect) -> some View {
        image
            .resizable()
            .frame(width: frame.width * scale, height: frame.height * scale)
            .offset(x: frame.minX * scale, y: frame.minY * scale)
    }
}

/// 접시만 남은 파르페 — 목록을 불러오지 못했을 때(G-001-Error) 쓴다.
struct EmptyParfaitCupView: View {
    let scale: CGFloat

    private var layout: ParfaitLayout { ParfaitLayout(groupCount: 0) }

    var body: some View {
        let frame = layout.cupFrame
        Image.parfaitCup
            .resizable()
            .frame(width: frame.width * scale, height: frame.height * scale)
            .offset(x: frame.minX * scale, y: frame.minY * scale)
            .frame(
                width: ParfaitLayout.designWidth * scale,
                height: layout.contentHeight * scale,
                alignment: .topLeading
            )
    }
}
