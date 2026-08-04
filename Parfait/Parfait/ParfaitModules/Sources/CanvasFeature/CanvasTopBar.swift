//
//  CanvasTopBar.swift
//  CanvasFeature
//
//  Created by 박서연 on 7/30/26.
//

import SwiftUI
import UIComponent

struct CanvasTopBar: View {
    let groupName: String
    let members: [CanvasStore.Member]
    let overflowMemberCount: Int
    let onBackTap: () -> Void
    let onMemberListTap: () -> Void
    let onMoreMenuTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            YGIconButton(.icCaretLeft, size: .small, action: onBackTap)

            Text(groupName)
                .suit(.body01Regular)
                .foregroundStyle(.gray800)
                .lineLimit(1)
                .padding(.leading, .padding2)

            Spacer(minLength: .gap2)

            Button(action: onMemberListTap) {
                HStack(spacing: -12) {
                    ForEach(members.prefix(5)) { member in
                        YGNametagChip(
                            nickname: member.nickname,
                            type: nametagType(for: member),
                            size: .medium
                        )
                    }

                    if overflowMemberCount > 0 {
                        YGNametagChip(overflowCount: overflowMemberCount)
                    }
                }
            }
            .buttonStyle(.plain)

            YGIconButton(.icHamburger, size: .small, action: onMoreMenuTap)
        }
        .padding(.horizontal, .padding3)
        .frame(maxWidth: .infinity)
        .frame(height: 60)
    }

    private func nametagType(for member: CanvasStore.Member) -> YGNametagChip.NametagType {
        let typeCount = YGNametagChip.NametagType.allCases.count
        let rawValue = Int(member.id.magnitude % UInt(typeCount)) + 1
        return YGNametagChip.NametagType(rawValue: rawValue) ?? .type1
    }
}
