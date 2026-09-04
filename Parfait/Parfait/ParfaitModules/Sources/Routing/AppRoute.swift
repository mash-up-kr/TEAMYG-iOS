//  앱 전역 네비게이션 목적지 = 모든 화면 전환의 단일 진실 소스.
//  페이로드는 Domain 엔티티(또는 원시값)로 넘긴다 — 목적지 피처가 소유한 타입은 금지(형제 import 유발).
//  엔티티가 생기면:  case group(Group)  처럼 바꾸고, Package.swift 의 Routing 의존에 "Domain" 추가.
public enum AppRoute: Hashable {
    /// 로그인 — 세션 만료(리프레시 토큰 거절) 시 `replaceStack(with: .login)` 으로 되돌아오는 목적지.
    case login
    /// 약관 동의 — 로그인이 `.signupRequired` 로 돌려준 가입 토큰을 들고 간다.
    case terms(registrationToken: String)
    case group
    /// 설정(S-001) — 그룹 목록(G-001) 상단 바 햄버거로 진입한다.
    case setting
    /// 캔버스(C-001) — 어느 그룹의 파르페인지 들고 간다.
    ///
    /// 그룹 목록(G-001)에서 토핑을 누르면 이 목적지로 온다. 페이로드는 `ParfaitGroup.id`·`name` 이다.
    /// 엔티티가 아니라 원시값으로 넘긴다 — Routing 이 GroupDomain 에 의존하지 않게 하려는 것이다.
    /// `groupName` 은 캔버스 상단 바 제목 — 캔버스 API 응답에 그룹명이 없어 진입점이 들고 간다.
    /// 이름을 모르는 진입점(푸시 탭)은 빈 문자열로 온다.
    case canvas(groupID: String, groupName: String)
}
