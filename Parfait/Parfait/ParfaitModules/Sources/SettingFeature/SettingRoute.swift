//
//  SettingRoute.swift
//  SettingFeature
//
//  Created by 김남수 on 7/22/26.
//

/// 설정 피처 내부 네비게이션 목적지. 피처 간 이동은 Routing 의 `AppRoute` 로,
/// 피처 안에서만 쓰는 화면은 여기로. (하이브리드 라우팅 규칙: docs/architecture.md)
public enum SettingRoute: Hashable {
    case accountInfo
}
