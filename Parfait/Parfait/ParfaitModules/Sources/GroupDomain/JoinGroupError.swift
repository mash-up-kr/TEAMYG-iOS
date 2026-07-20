//
//  JoinGroupError.swift
//  GroupDomain
//
//  Created by 김남수 on 7/15/26.
//

/// 그룹 참여 실패 사유. Data 레이어가 서버 에러 응답을 이 타입으로 매핑한다.
/// 표시 문구는 UI 레이어가 결정하고, 여기는 의미만 담는다.
public enum JoinGroupError: Error, Equatable {
    case invalidInviteCode
    case groupFull
    case alreadyJoined
    /// 매핑되지 않은 서버 에러 — 서버가 내려준 메시지를 그대로 전달.
    case server(message: String)
    /// 사유 불명(네트워크 단절 등) — View 가 일반 안내 문구로 렌더링.
    case unknown
}
