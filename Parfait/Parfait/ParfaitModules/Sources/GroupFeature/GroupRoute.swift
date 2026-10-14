//
//  GroupRoute.swift
//  GroupFeature
//
//  Created by 김남수 on 7/15/26.
//

/// 그룹 피처 내부 네비게이션 목적지. 피처 간 이동은 Routing 의 `AppRoute` 로,
/// 피처 안에서만 쓰는 화면은 여기로 — App 은 딥링크 매핑 때만 이 타입을 안다.
/// (하이브리드 라우팅 규칙: docs/architecture.md)
public enum GroupRoute: Hashable {
    /// `prefilledCode` — 초대 링크(`/link?inviteCode=`)로 들어오면 그 코드를 미리 채운다.
    case inviteCode(prefilledCode: String = "")
    case createGroup
}
