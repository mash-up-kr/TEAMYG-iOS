//  앱 전역 네비게이션 목적지 = 모든 화면 전환의 단일 진실 소스.
//  페이로드는 Domain 엔티티(또는 원시값)로 넘긴다 — 목적지 피처가 소유한 타입은 금지(형제 import 유발).
//  엔티티가 생기면:  case group(Group)  처럼 바꾸고, Package.swift 의 Routing 의존에 "Domain" 추가.
public enum AppRoute: Hashable {
    case group
    case canvas
}
