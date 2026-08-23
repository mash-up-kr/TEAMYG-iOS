//
//  ParfaitGroup.swift
//  GroupDomain
//
//  Created by 신상우 on 8/1/26.
//

import Foundation

/// 사용자가 속한 그룹 하나. 그룹 목록(G-001)에서 파르페 위 토핑 한 개로 그려진다.
public struct ParfaitGroup: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    /// 대표 토핑 이미지. 아직 토핑이 하나도 없는 그룹은 nil — UI 가 템플릿 그래픽으로 대체한다.
    public let thumbnailURL: URL?
    /// 마지막 토핑 업로드 시각. 목록 정렬 기준이자 칩 타임스탬프의 기준이다.
    ///
    /// 아직 토핑이 하나도 없는 그룹은 nil — 칩이 타임스탬프 없이 이름만 보여준다.
    public let lastActivityAt: Date?
    /// 마지막으로 토핑을 올린 그룹원의 Nametag 계열 — 칩 타임스탬프 색을 결정한다.
    ///
    /// 토핑이 없는 그룹은 nil 이고, 색을 모를 때도 nil 이다. UI 는 기본 계열 색으로 그린다.
    public let lastActorNametagType: NametagType?

    public init(
        id: String,
        name: String,
        thumbnailURL: URL?,
        lastActivityAt: Date?,
        lastActorNametagType: NametagType?
    ) {
        self.id = id
        self.name = name
        self.thumbnailURL = thumbnailURL
        self.lastActivityAt = lastActivityAt
        self.lastActorNametagType = lastActorNametagType
    }
}
