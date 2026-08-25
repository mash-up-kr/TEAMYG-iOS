//
//  MyParfaitGroupDTO.swift
//  GroupData
//
//  Created by 신상우 on 8/17/26.
//

import Core
import Foundation
import GroupDomain

/// `MyParfaitGroupResponse` 스키마 대응 (`GET /api/parfait-groups`).
struct MyParfaitGroupDTO: Decodable, Sendable {
    let groupId: Int
    let groupName: String
    let recentImageUrl: String?
    /// 마지막 토핑 업로드 시각. `Date` 가 아니라 문자열로 받는다 — 이유는 `ServerDate` 주석 참고.
    let recentImageUploadedAt: String?
    /// 마지막으로 토핑을 올린 그룹원의 Nametag 계열. 값은 `NametagChipCode` 참고.
    let lastPlacedByNametagChip: String?
}

extension MyParfaitGroupDTO {
    /// 서버가 주지 않는 값은 채우지 않고 nil 로 올린다. 그럴듯한 기본값을 지어내면
    /// "데이터가 없다" 와 "이런 값이다" 가 화면에서 구분되지 않는다.
    func toEntity() -> ParfaitGroup {
        ParfaitGroup(
            id: String(groupId),
            name: groupName,
            thumbnailURL: recentImageUrl.flatMap { URL(string: $0) },
            lastActivityAt: recentImageUploadedAt.flatMap { ServerDate.date(from: $0) },
            lastActorNametagType: lastPlacedByNametagChip.flatMap { NametagChipCode.nametagType(from: $0) }
        )
    }
}
