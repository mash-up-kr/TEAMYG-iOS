//
//  ParfaitMember.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 캔버스를 함께 쓰는 그룹원. 상단 바 네임태그와 토핑 배치자 표기에 쓴다.
public struct ParfaitMember: Identifiable, Equatable, Sendable {
    public let id: Int
    public let nickname: String
    public let nametagChip: NametagChip

    public init(id: Int, nickname: String, nametagChip: NametagChip) {
        self.id = id
        self.nickname = nickname
        self.nametagChip = nametagChip
    }
}
