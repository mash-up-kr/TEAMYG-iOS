//
//  CanvasEntryNudge.swift
//  CanvasFeature
//
//  Created by 박서연 on 10/9/26.
//

import SwiftUI
import UIComponent

struct CanvasEntryNudge: View {
    let nudge: CanvasStore.EntryNudge

    var body: some View {
        CanvasNudgeBar(
            titleText: nudge.titleText,
            descriptionText: nudge.descriptionText,
            action: nudge.inviteCode.map { inviteCode in
                CanvasNudgeBar.Action(
                    title: "공유하기",
                    kind: .share(YGInviteCard.inviteMessage(code: inviteCode))
                )
            }
        )
    }
}
