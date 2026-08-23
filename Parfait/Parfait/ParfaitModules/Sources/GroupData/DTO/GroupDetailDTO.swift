//
//  GroupDetailDTO.swift
//  GroupData
//
//  Created by 신상우 on 8/20/26.
//

import GroupDomain

/// `MyParfaitGroupDetailResponse` 스키마 대응 — 그룹 상세(`GET /api/parfait-groups/{groupId}`).
struct GroupDetailDTO: Decodable, Sendable {
    let groupId: Int
    let groupName: String
    /// 이 그룹에서 쓰는 **내** 닉네임. 구성원 목록과 별개로 최상위에 한 번 더 내려온다.
    let groupNickname: String
    let inviteCode: String
    let memberLimit: Int
    let members: [GroupMemberDTO]
}

extension GroupDetailDTO {
    /// Domain 의 `GroupDetail` 로 옮긴다. 본인(`isMe`)이 맨 앞에 오는 정렬까지 여기서 맞춘다 —
    /// Domain 이 "서버(또는 Data)가 보장한다" 고 약속한 몫이다.
    ///
    /// ponytail: 응답에 본인 표시(`isMe`·`myMemberId`)가 없어 **최상위 `groupNickname` 과 같은
    ///           닉네임의 구성원**을 나로 본다. 같은 닉네임이 둘 있으면 첫 줄만 나로 잡는다 —
    ///           내 닉네임 자체는 최상위 값이라 항상 맞고, 어긋날 수 있는 건 "(나)" 표시 줄뿐이다.
    ///           서버에 본인 식별 필드를 요청해 두었고, 들어오면 그 값으로 교체한다.
    func toEntity() -> GroupDetail {
        var isMyMemberFound = false
        let members = members.map { member in
            let isMe = !isMyMemberFound && member.groupNickname == groupNickname
            if isMe { isMyMemberFound = true }
            return GroupMember(
                id: String(member.memberId),
                nickname: member.groupNickname,
                nametagType: member.nameTagChip.flatMap { NametagChipCode.nametagType(from: $0) },
                isMe: isMe
            )
        }
        return GroupDetail(
            id: String(groupId),
            name: groupName,
            inviteCode: inviteCode,
            memberLimit: memberLimit,
            // 나머지 구성원의 순서는 서버가 준 순서를 그대로 둔다.
            members: members.filter(\.isMe) + members.filter { !$0.isMe }
        )
    }
}

/// `ParfaitGroupMemberResponse` 스키마 대응 — 상세 응답의 구성원 한 명.
struct GroupMemberDTO: Decodable, Sendable {
    let memberId: Int
    let groupNickname: String
    /// Nametag 계열 코드. 값은 `NametagChipCode` 참고.
    let nameTagChip: String?
}
