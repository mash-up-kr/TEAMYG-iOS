//
//  NametagChip.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 그룹원 네임태그 계열. 서버가 `TYPE1`~`TYPE12` 또는 `DEFAULT` 로 내려준다.
/// `GroupDomain.NametagType` 과 값이 같지만 모듈 경계가 달라 각자 소유한다.
public enum NametagChip: Int, Sendable, Hashable, CaseIterable {
    case type1 = 1, type2, type3, type4, type5, type6
    case type7, type8, type9, type10, type11, type12
    /// 아직 배정되지 않았거나 알 수 없는 그룹원.
    case unassigned = 0

    public var number: Int? {
        self == .unassigned ? nil : rawValue
    }

    public init(number: Int) {
        self = Self(rawValue: number) ?? .unassigned
    }
}
