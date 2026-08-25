//
//  NametagChipCode.swift
//  GroupData
//
//  Created by 신상우 on 8/17/26.
//

import GroupDomain

/// 서버의 Nametag 계열 코드 → Domain 의 `NametagType`.
///
/// 코드는 `TYPE1`~`TYPE12` 와 색 없는 값이다. 앞의 12개만 색을 가지므로 번호를 떼어 옮기고,
/// 그 밖의 값은 nil 로 접는다. `Decodable` 열거형으로 받지 않는 이유는 서버가 코드를 하나
/// 추가하는 순간 응답 전체의 디코딩이 깨지기 때문이다. 색 하나를 모르는 건 그 항목의 칩만
/// 기본색이 되는 일이라, 목록을 통째로 잃는 것과 무게가 다르다.
///
/// 색 없는 값의 이름이 스웨거와 달라진 적이 있다 — 그룹 목록을 붙일 때는 `RELEASED`,
/// 지금 스웨거는 `DEFAULT` 다. 접두어만 보고 접으므로 어느 쪽이 와도 동작은 같다.
///
/// ponytail: 색 없는 값의 뜻을 확인해 색 없이 두는 게 맞는지 정한다 (#77).
///           탈퇴로 Nametag 가 반납된 상태로 보이는데, 그렇다면 마지막 작성자의 색을
///           무엇으로 그릴지는 디자인 결정이 필요하다.
enum NametagChipCode {
    private static let typePrefix = "TYPE"

    static func nametagType(from code: String) -> NametagType? {
        guard code.hasPrefix(typePrefix) else { return nil }
        return Int(code.dropFirst(typePrefix.count)).flatMap(NametagType.init(rawValue:))
    }
}
