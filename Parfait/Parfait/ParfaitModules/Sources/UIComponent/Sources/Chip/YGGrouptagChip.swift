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
/// 타임스탬프 색은 유저의 `YGNametagChip.NametagType` 에 강제 매핑된다
/// (토스트 닉네임 색 `toastNicknameColor` 보다 한 단계 낮은 색 — 디자이너 확정).
public struct YGGrouptagChip: View {
    /// 그룹명이 차지할 수 있는 최대 너비. 넘으면 넘친 만큼 말줄임한다.
    /// 글자 수가 아니라 너비 기준 — 같은 글자 수라도 폭이 다르기 때문(디자이너 확정).
    private static let maximumNameWidth: CGFloat = 80

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
                .truncationMode(.tail)
                .frame(maxWidth: Self.maximumNameWidth, alignment: .leading)
                .foregroundStyle(.whiteFixed)
            Circle()
                .fill(.white50)
                .frame(width: 1, height: 1)
            Text(timestamp)
                .suit(.caption01Regular)
                .lineLimit(1)
                .foregroundStyle(type.timestampColor)
        }
        .padding(.vertical, .padding2)
        .padding(.horizontal, .padding5)
        .background(.black75, in: .capsule)
    }
}

// MARK: - 타입별 Timestamp 색

private extension YGNametagChip.NametagType {
    /// Grouptag Timestamp 색 — Figma 실측 기준. `toastNicknameColor` 보다 한 단계 낮다.
    var timestampColor: Color {
        switch self {
        case .type1, .type2: return .cherry100
        case .type3, .type4: return .cherry200
        case .type5, .type6: return .cherry300
        case .type7, .type8: return .gray200
        case .type9, .type10: return .melon500
        case .type11, .type12: return .pudding500
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: .gap5) {
        YGGrouptagChip(name: "잠탈감금", timestamp: "3분전", type: .type1)
        YGGrouptagChip(name: "팀와지", timestamp: "3분전", type: .type3)
        // 80pt 를 넘겨 말줄임되는 경우
        YGGrouptagChip(name: "아주아주긴그룹이름입니다", timestamp: "3분전", type: .type5)
        YGGrouptagChip(name: "잠탈감금2", timestamp: "3분전", type: .type7)
        YGGrouptagChip(name: "다섯글자임", timestamp: "3분전", type: .type9)
        YGGrouptagChip(name: "이름", timestamp: "3분전", type: .type11)
    }
    .padding()
}
