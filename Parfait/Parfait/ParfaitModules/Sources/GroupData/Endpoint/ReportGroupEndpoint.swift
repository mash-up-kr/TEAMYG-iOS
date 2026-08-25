//
//  ReportGroupEndpoint.swift
//  GroupData
//
//  Created by 신상우 on 8/20/26.
//

import Core

/// 그룹 신고 (`POST /api/parfait-groups/{groupId}/reports`).
/// 접수되면 서버가 탈퇴까지 함께 처리한다 — 이 요청 하나로 끝이라 별도의 나가기 호출이 없다.
struct ReportGroupEndpoint: Endpoint {
    /// 서버가 사유를 필수로 받는데(빈 문자열이면 `INVALID_GROUP_REPORT_REASON`),
    /// 신고 팝업(S-103)에는 사유 입력이 없다 — 확인만 누르면 접수되는 디자인이다.
    /// 그래서 앱에서 온 신고임을 알 수 있는 고정 문구를 보낸다.
    ///
    /// ponytail: 사유 입력 UI 가 생기거나 서버가 사유를 선택값으로 바꾸면 이 상수는 지운다.
    static let fixedReason = "앱 내 그룹 신고"

    let groupID: String

    var path: String { "/api/parfait-groups/\(groupID)/reports" }
    var method: HTTPMethod { .post }
    var task: RequestTask { .body(Body(reason: Self.fixedReason)) }

    struct Body: Encodable, Sendable {
        let reason: String
    }
}
