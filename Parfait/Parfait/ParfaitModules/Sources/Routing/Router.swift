//  라우팅 추상화. 피처는 이걸 "주입받아 호출"만 한다(피처 내 라우팅).
//  구현체(NavigationPath 보유)는 App 이 소유 — App 만이 AppRoute → 실제 View 를 조립한다.
@MainActor
public protocol Router: AnyObject {
    func push(_ route: AppRoute)
    func pop()
    /// 스택을 비우고 `route` 를 새 루트로 시작한다 — 뒤로가기로 이전 화면에 돌아갈 수 없다.
    /// 로그인/회원가입 완료 → 메인 전환처럼 이전 플로우를 끝내는 지점에서 쓴다.
    func replaceStack(with route: AppRoute)
}
