//
//  YGUserChip.swift
//  UIComponent
//
//  Created by 신상우 on 7/15/26.
//

import SwiftUI

/// 파르페 유저 칩 컴포넌트.
///
/// Figma `User-Chip` 컴포넌트셋. 네임태그(`YGNametagChip` large) + 닉네임으로 구성되며,
/// 본인 여부(`isSelf`)에 따라 닉네임 스타일이 달라진다 (본인이면 SemiBold · 더 진한 색).
public struct YGUserChip: View {
    private let nickname: String
    private let type: YGNametagChip.NametagType
    private let isSelf: Bool

    public init(nickname: String, type: YGNametagChip.NametagType, isSelf: Bool) {
        self.nickname = nickname
        self.type = type
        self.isSelf = isSelf
    }

    public var body: some View {
        HStack(spacing: .gap3) {
            YGNametagChip(nickname: nickname, type: type, size: .large)
            Text(nickname)
                .suit(isSelf ? .body02SemiBold : .body02Regular)
                .lineLimit(1)
                .foregroundStyle(isSelf ? .gray950 : .gray800)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: .gap5) {
        YGUserChip(nickname: "아니야나그런데기니야기니라니까", type: .type4, isSelf: true)
        YGUserChip(nickname: "아니야나그런데기니야기니라니까", type: .type4, isSelf: false)
    }
    .padding()
}
