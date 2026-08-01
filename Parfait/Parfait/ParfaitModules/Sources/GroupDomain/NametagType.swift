//
//  NametagType.swift
//  GroupDomain
//
//  Created by 신상우 on 8/1/26.
//

/// Nametag 타입(1~12). 6개 컬러 계열 × 2타입이며, 계정 생성 시 1회 배정된 뒤 바뀌지 않는다.
///
/// 그룹 목록의 Grouptag-Chip 타임스탬프 색이 이 값에 강제 매핑된다 — 랜덤이 아니다.
/// 실제 색은 UI 레이어(`YGNametagChip.NametagType`)가 정하고, Domain 은 번호만 안다.
public enum NametagType: Int, Sendable, Hashable, CaseIterable {
    case type1 = 1
    case type2
    case type3
    case type4
    case type5
    case type6
    case type7
    case type8
    case type9
    case type10
    case type11
    case type12
}
