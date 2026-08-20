//
//  GroupMember.swift
//  GroupDomain
//
//  Created by 신상우 on 8/10/26.
//

/// 그룹에 속한 구성원 한 명. 그룹 사이드메뉴(S-101)의 그룹원 목록 한 줄로 그려진다.
public struct GroupMember: Sendable, Identifiable, Hashable {
    public let id: String
    public let nickname: String
    /// 프로필 이미지(Nametag-Chip) 색 계열 — 계정 생성 시 1회 배정, 불변.
    public let nametagType: NametagType
    /// 조회한 본인인지. 목록 맨 위 "(나)" 표기·닉네임 강조의 기준.
    public let isMe: Bool

    public init(id: String, nickname: String, nametagType: NametagType, isMe: Bool) {
        self.id = id
        self.nickname = nickname
        self.nametagType = nametagType
        self.isMe = isMe
    }
}
