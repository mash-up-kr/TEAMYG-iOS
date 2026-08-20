//
//  GroupDetail.swift
//  GroupDomain
//
//  Created by 신상우 on 8/10/26.
//

/// 그룹 하나의 상세 — 사이드메뉴(S-101)가 그리는 단위.
/// 목록용 `ParfaitGroup` 과 달리 구성원·초대 코드까지 들고 있다.
public struct GroupDetail: Sendable, Hashable {
    public let id: String
    public let name: String
    /// 6자리 영대문자·숫자 초대 코드.
    public let inviteCode: String
    /// 그룹 생성 시 확정된 최대 인원(1~12) — 이후 변경 불가.
    public let memberLimit: Int
    /// 구성원 목록. 본인(`isMe`)이 맨 앞에 오는 정렬은 서버(또는 Data)가 보장한다.
    public let members: [GroupMember]

    public init(
        id: String,
        name: String,
        inviteCode: String,
        memberLimit: Int,
        members: [GroupMember]
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.memberLimit = memberLimit
        self.members = members
    }

    /// 초대 가능한 남은 자리 수. 0 이면 초대 코드 카드가 "최대 인원 도달" 로 바뀐다.
    public var remainingSeatCount: Int {
        max(0, memberLimit - members.count)
    }

    /// 이 그룹에서 쓰는 내 닉네임. 구성원에 내가 없으면(비정상 응답) nil.
    public var myNickname: String? {
        members.first(where: \.isMe)?.nickname
    }

    /// 내 닉네임만 바꾼 사본 — 닉네임 변경 성공 시 화면 상태 갱신용.
    public func updatingMyNickname(_ nickname: String) -> GroupDetail {
        GroupDetail(
            id: id,
            name: name,
            inviteCode: inviteCode,
            memberLimit: memberLimit,
            members: members.map { member in
                guard member.isMe else { return member }
                return GroupMember(
                    id: member.id,
                    nickname: nickname,
                    nametagType: member.nametagType,
                    isMe: true
                )
            }
        )
    }
}
