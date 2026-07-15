//
//  YGGrouptagChip.swift
//  UIComponent
//
//  Created by 신상우 on 7/15/26.
//

import SwiftUI

/// 파르페 그룹태그 칩 컴포넌트.
///
/// Figma `Grouptag-Chip` 컴포넌트셋. 이름 + 점 디바이더 + 타임스탬프가 든 어두운 캡슐로,
/// 타임스탬프 색은 유저의 `YGNametagChip.NametagType` 강조색(`accentColor`)에 강제 매핑된다.
public struct YGGrouptagChip: View {
    private let name: String
    private let timestamp: String
    private let type: YGNametagChip.NametagType

    public init(name: String, timestamp: String, type: YGNametagChip.NametagType) {
        self.name = name
        self.timestamp = timestamp
        self.type = type
    }

    public var body: some View {
        HStack(spacing: .gap2) {
            Text(name)
                .suit(.body02SemiBold)
                .lineLimit(1)
                .foregroundStyle(.whiteFixed)
            Circle()
                .fill(.white50)
                .frame(width: 1, height: 1)
            Text(timestamp)
                .suit(.caption01Regular)
                .lineLimit(1)
                .foregroundStyle(type.accentColor)
        }
        .padding(.vertical, .padding3)
        .padding(.horizontal, .padding6)
        .background(.black75, in: .capsule)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: .gap5) {
        YGGrouptagChip(name: "잠탈감금", timestamp: "3분전", type: .type1)
        YGGrouptagChip(name: "팀와지", timestamp: "3분전", type: .type3)
        YGGrouptagChip(name: "팀장은연경...", timestamp: "3분전", type: .type5)
        YGGrouptagChip(name: "잠탈감금2", timestamp: "3분전", type: .type7)
        YGGrouptagChip(name: "다섯글자임", timestamp: "3분전", type: .type9)
        YGGrouptagChip(name: "이름", timestamp: "3분전", type: .type11)
    }
    .padding()
}
