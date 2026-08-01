//
//  YGGroup.swift
//  GroupDomain
//
//  Created by 신상우 on 8/1/26.
//

import Foundation

/// 사용자가 속한 그룹 하나. 그룹 목록(G-001)에서 파르페 위 토핑 한 개로 그려진다.
public struct YGGroup: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    /// 대표 토핑 이미지. 아직 토핑이 하나도 없는 그룹은 nil — UI 가 템플릿 그래픽으로 대체한다.
    public let thumbnailURL: URL?
    /// 마지막 변화(토핑 추가·편집, 배경 추가·변경) 시각. 목록 정렬 1순위이자 칩 타임스탬프의 기준.
    public let lastActivityAt: Date
    /// 그룹 생성 시각. `lastActivityAt` 이 밀리초까지 같을 때의 정렬 2순위.
    public let createdAt: Date
    /// 마지막으로 변화를 가한 그룹원의 Nametag 계열 — 칩 타임스탬프 색을 결정한다.
    public let lastActorNametagType: NametagType

    public init(
        id: String,
        name: String,
        thumbnailURL: URL?,
        lastActivityAt: Date,
        createdAt: Date,
        lastActorNametagType: NametagType
    ) {
        self.id = id
        self.name = name
        self.thumbnailURL = thumbnailURL
        self.lastActivityAt = lastActivityAt
        self.createdAt = createdAt
        self.lastActorNametagType = lastActorNametagType
    }
}
