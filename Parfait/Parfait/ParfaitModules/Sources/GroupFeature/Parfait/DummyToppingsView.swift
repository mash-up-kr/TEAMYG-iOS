//
//  DummyToppingsView.swift
//  GroupFeature
//
//  Created by 박서연 on 10/10/26.
//

import SwiftUI
import UIComponent

struct DummyToppingsView: View {
    let revealedCount: Int
    let isSettled: Bool
    let scale: CGFloat

    private static let revealAnimation = Animation.timingCurve(0, 0, 0, 1, duration: 1)
    private static let revealOffsetY: CGFloat = -60

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(DummyGroup.all.enumerated()), id: \.offset) { index, dummyGroup in
                let isRevealed = index < revealedCount
                ToppingFrameView(variant: dummyGroup.variant, scale: scale, chip: dummyGroup.chip) {
                    dummyGroup.image
                        .resizable()
                        .scaledToFit()
                }
                .opacity(isRevealed ? 1 : 0)
                .offset(
                    x: dummyGroup.origin.x * scale,
                    y: (dummyGroup.origin.y + (isRevealed ? 0 : Self.revealOffsetY)) * scale
                )
                .animation(isRevealed && !isSettled ? Self.revealAnimation : nil, value: isRevealed)
            }
        }
        .frame(
            width: ParfaitLayout.designWidth * scale,
            height: ParfaitLayout(groupCount: 0).contentHeight * scale,
            alignment: .topLeading
        )
    }
}

private struct DummyGroup {
    let image: Image
    let chip: YGGrouptagChip
    let variant: ToppingVariant
    let origin: CGPoint

    static var all: [DummyGroup] {
        [
            DummyGroup(
                image: .imageGroupList1,
                chip: YGGrouptagChip(name: "예카수집가", timestamp: "1분전", type: .type5),
                variant: .variant(forSide: false, number: 1),
                origin: CGPoint(x: ParfaitLayout.leftColumnX, y: ParfaitLayout.leftColumnFirstY)
            ),
            DummyGroup(
                image: .imageGroupList2,
                chip: YGGrouptagChip(name: "파르페", timestamp: "2분전", type: .type1),
                variant: .variant(forSide: true, number: 0),
                origin: CGPoint(x: ParfaitLayout.rightColumnX, y: 204)
            ),
            DummyGroup(
                image: .imageGroupList3,
                chip: YGGrouptagChip(name: "일상", timestamp: "3분전", type: .type3),
                variant: .variant(forSide: false, number: 1),
                origin: CGPoint(
                    x: ParfaitLayout.leftColumnX,
                    y: ParfaitLayout.leftColumnFirstY + ParfaitLayout.columnStep
                )
            )
        ]
    }
}
