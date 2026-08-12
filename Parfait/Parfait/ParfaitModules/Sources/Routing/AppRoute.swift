//  앱 전역 네비게이션 목적지 = 모든 화면 전환의 단일 진실 소스.
//  페이로드는 Domain 엔티티(또는 원시값)로 넘긴다 — 목적지 피처가 소유한 타입은 금지(형제 import 유발).
//  엔티티가 생기면:  case group(Group)  처럼 바꾸고, Package.swift 의 Routing 의존에 "Domain" 추가.
public enum AppRoute: Hashable {
    /// 로그인 — 세션 만료(리프레시 토큰 거절) 시 `replaceStack(with: .login)` 으로 되돌아오는 목적지.
    case login
    /// 약관 동의 — 로그인이 `.signupRequired` 로 돌려준 가입 토큰을 들고 간다.
    case terms(registrationToken: String)
    case group
    case canvas
}
