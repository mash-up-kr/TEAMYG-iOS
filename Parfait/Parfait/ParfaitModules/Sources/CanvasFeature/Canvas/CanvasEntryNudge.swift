//
//  CanvasEntryNudge.swift
//  CanvasFeature
//
//  Created by 박서연 on 10/9/26.
//

import SwiftUI
import UIComponent
import UIKit

struct CanvasEntryNudge: View {
    let nudge: CanvasStore.EntryNudge

    @State private var isInviteCodeCopied = false

    var body: some View {
        CanvasNudgeBar(
            titleText: nudge.titleText,
            descriptionText: nudge.descriptionText,
            action: nudge.inviteCode.map { inviteCode in
                CanvasNudgeBar.Action(
                    title: isInviteCodeCopied ? "복사완료" : "복사하기",
                    icon: .icCopy
                ) {
                    UIPasteboard.general.string = inviteCode
                    isInviteCodeCopied = true
                }
            }
        )
    }
}
