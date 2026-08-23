//
//  MyParfaitGroupDTO.swift
//  GroupData
//
//  Created by 신상우 on 8/17/26.
//

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

/// 서버의 Nametag 계열 코드 → Domain 의 `NametagType`.
///
/// 코드는 `TYPE1`~`TYPE12` 와 `RELEASED` 다. 앞의 12개만 색을 가지므로 번호를 떼어 옮기고,
/// 그 밖의 값은 nil 로 접는다. `Decodable` 열거형으로 받지 않는 이유는 서버가 코드를 하나
/// 추가하는 순간 목록 전체의 디코딩이 깨지기 때문이다. 색 하나를 모르는 건 그 그룹의 칩만
/// 기본색이 되는 일이라, 목록을 통째로 잃는 것과 무게가 다르다.
///
/// ponytail: `RELEASED` 의 뜻을 확인해 색 없이 두는 게 맞는지 정한다 (#77).
///           탈퇴로 Nametag 가 반납된 상태로 보이는데, 그렇다면 마지막 작성자의 색을
///           무엇으로 그릴지는 디자인 결정이 필요하다.
enum NametagChipCode {
    private static let typePrefix = "TYPE"

    static func nametagType(from code: String) -> NametagType? {
        guard code.hasPrefix(typePrefix) else { return nil }
        return Int(code.dropFirst(typePrefix.count)).flatMap(NametagType.init(rawValue:))
    }
}

/// 서버 날짜 문자열 → `Date`.
///
/// 공용 디코더(`NetworkClientImpl` 의 `.iso8601`)에 맡기지 않고 문자열로 받아 여기서 옮긴다.
/// 개발 서버의 그룹이 모두 `recentImageUploadedAt: null` 이라 실제 값을 확인하지 못했기 때문이다.
/// 오프셋 없는 `LocalDateTime` 이 내려오면 `.iso8601` 은 디코딩 자체를 실패시켜 목록 전체가 날아가는데,
/// 문자열로 받으면 못 읽는 포맷이 와도 그 그룹의 활동 시각만 nil 이 되고 목록은 그대로 그려진다.
///
/// ponytail: 실제 값을 확인하면 포맷을 확정하고 공용 디코더로 옮긴다 (#77).
///           스웨거 예시는 `2026-08-18T10:29:58.822Z` 로, 아래가 읽는 형태와 같다.
enum ServerDate {
    /// 오프셋(`Z`·`+09:00`)이 붙은 ISO8601 만 읽는다. 소수점 초는 있어도 되고 없어도 된다.
    ///
    /// 오프셋이 없으면 읽지 않고 nil 을 준다 — 어느 시간대인지 알 수 없어서다.
    /// 임의로 정해 버리면 방금 올린 토핑이 "9시간 전" 으로 보이는 식의 거짓 문구가 된다.
    /// 없는 편이 틀린 것보다 낫다.
    static func date(from text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}
