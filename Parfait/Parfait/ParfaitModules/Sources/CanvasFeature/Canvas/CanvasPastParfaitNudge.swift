//
//  CanvasPastParfaitNudge.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/27/26.
//

import SwiftUI
import UIComponent

struct CanvasPastParfaitNudge: View {
    let nudge: CanvasStore.PastParfaitNudge
    let onOpenTap: () -> Void

    var body: some View {
        CanvasNudgeBar(
            titleText: nudge.titleText,
            descriptionText: nudge.descriptionText,
            action: CanvasNudgeBar.Action(title: "보러가기", icon: .icCaretRight, handler: onOpenTap)
        )
    }
}

#Preview("SY-001-New") {
    CanvasPastParfaitNudge(
        nudge: .init(
            date: CalendarDate(year: 2026, month: 12, day: 31),
            friendCount: 12
        ),
        onOpenTap: {}
    )
    .frame(width: 375)
    .background(.gray100)
}
