//  라우팅 추상화. 피처는 이걸 "주입받아 호출"만 한다(피처 내 라우팅).
//  구현체(NavigationPath 보유)는 App 이 소유 — App 만이 AppRoute → 실제 View 를 조립한다.
@MainActor
public protocol Router: AnyObject {
    func push(_ route: AppRoute)
    func pop()
}
