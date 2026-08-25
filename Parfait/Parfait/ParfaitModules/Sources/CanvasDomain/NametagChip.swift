//
//  NametagChip.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 그룹원 네임태그 계열. 서버가 `TYPE1`~`TYPE12` 또는 `DEFAULT` 로 내려준다.
/// `GroupDomain.NametagType` 과 값이 같지만 모듈 경계가 달라 각자 소유한다.
public enum NametagChip: Sendable, Hashable, CaseIterable {
    case type1, type2, type3, type4, type5, type6
    case type7, type8, type9, type10, type11, type12
    /// 아직 배정되지 않았거나 알 수 없는 그룹원.
    case unassigned

    public var number: Int? {
        Self.numbered.firstIndex(of: self).map { $0 + 1 }
    }

    public init(number: Int) {
        self = Self.numbered.indices.contains(number - 1) ? Self.numbered[number - 1] : .unassigned
    }

    private static let numbered: [Self] = [
        .type1, .type2, .type3, .type4, .type5, .type6,
        .type7, .type8, .type9, .type10, .type11, .type12
    ]
}
