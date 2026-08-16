//
//  CreateGroupResponseDTO.swift
//  GroupData
//
//  Created by 신상우 on 8/17/26.
//

/// `CreateParfaitGroupResponse` 스키마 대응 (`POST /api/parfait-groups`).
///
/// `inviteCode` 는 아직 쓰는 화면이 없다. 그래도 받아 두는 건 서버가 생성 응답에서만 내려주기
/// 때문이다 — 그룹 공유(초대) 화면이 붙을 때 재조회 없이 쓰려면 여기서 잃지 않아야 한다.
struct CreateGroupResponseDTO: Decodable, Sendable {
    let groupId: Int
    let groupName: String
    let inviteCode: String
    let memberLimit: Int
}
