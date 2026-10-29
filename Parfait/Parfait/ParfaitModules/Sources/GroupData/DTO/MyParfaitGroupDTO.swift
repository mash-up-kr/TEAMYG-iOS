//
//  MyParfaitGroupDTO.swift
//  GroupData
//
//  Created by 신상우 on 8/17/26.
//

import Core
import Foundation
import GroupDomain

/// `MyParfaitGroupV2Response` 스키마 대응 (`GET /api/v2/parfait-groups`).
struct MyParfaitGroupDTO: Decodable, Sendable {
    let groupId: Int
    let groupName: String
    /// 마지막 토핑 종류 (`IMAGE`·`TEXT`). 텍스트면 `recentImageUrl` 이 null 이다.
    let recentToppingType: String?
    let recentImageUrl: String?
    let recentImageBorderType: String?
    let recentImageBorderColor: String?
    /// 마지막 토핑 업로드 시각. `Date` 가 아니라 문자열로 받는다 — 이유는 `ServerDate` 주석 참고.
    let recentImageUploadedAt: String?
    let lastPlacedByNameTagChip: String?
}

extension MyParfaitGroupDTO {
    /// 서버가 주지 않는 값은 채우지 않고 nil 로 올린다. 그럴듯한 기본값을 지어내면
    /// "데이터가 없다" 와 "이런 값이다" 가 화면에서 구분되지 않는다.
    func toEntity() -> ParfaitGroup {
        ParfaitGroup(
            id: String(groupId),
            name: groupName,
            thumbnailURL: recentImageUrl.flatMap { URL(string: $0) },
            thumbnailBorderColorHex: thumbnailBorderColorHex,
            latestToppingKind: latestToppingKind,
            lastActivityAt: recentImageUploadedAt.flatMap { ServerDate.date(from: $0) },
            lastActorNametagType: lastPlacedByNameTagChip
                .flatMap { NametagChipCode.number(from: $0) }
                .flatMap { NametagType(rawValue: $0) }
        )
    }

    private var latestToppingKind: ParfaitGroup.ToppingKind? {
        switch recentToppingType {
        case "IMAGE": .image
        case "TEXT": .text
        default: nil
        }
    }

    private var thumbnailBorderColorHex: String? {
        guard
            recentImageBorderType == "SOLID",
            let recentImageBorderColor,
            recentImageBorderColor.count == 7,
            recentImageBorderColor.hasPrefix("#"),
            recentImageBorderColor.dropFirst().allSatisfy(\.isHexDigit)
        else {
            return nil
        }
        return recentImageBorderColor
    }
}
