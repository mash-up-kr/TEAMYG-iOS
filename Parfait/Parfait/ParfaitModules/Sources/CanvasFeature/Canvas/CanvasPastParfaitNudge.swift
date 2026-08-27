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
        HStack(spacing: .gap6) {
            message
            openButton
        }
        .padding(.horizontal, .padding7)
        .padding(.vertical, .padding5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { Color.black75.allowsHitTesting(false) }
    }

    private var message: some View {
        VStack(alignment: .leading, spacing: .gap2) {
            Text(nudge.titleText)
                .suit(.body02SemiBold)
                .foregroundStyle(.cherry200)

            Text(nudge.descriptionText)
                .suit(.body02Regular)
                .foregroundStyle(.white75)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    private var openButton: some View {
        Button(action: onOpenTap) {
            HStack(spacing: .gap2) {
                Text("보러가기")
                    .suit(.body02Regular)
                    .foregroundStyle(.gray950)

                Image.icCaretRight
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(.gray950)
                    .frame(width: 16, height: 16)
            }
            .padding(.leading, .padding5)
            .padding(.trailing, .padding3)
            .padding(.vertical, .padding2)
            .background(.cherry100, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .fixedSize()
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
