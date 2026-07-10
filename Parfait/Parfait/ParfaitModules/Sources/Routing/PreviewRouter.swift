//
//  PreviewRouter.swift
//  Routing
//
//  Created by 김남수 on 7/3/26.
//

#if DEBUG
/// Preview 용 no-op 라우터. 네비게이션이 필요 없는 단일 화면 프리뷰에 주입한다.
public final class PreviewRouter: Router {
    public init() {}
    public func push(_ route: AppRoute) {}
    public func pop() {}
}

public extension Router where Self == PreviewRouter {
    /// `LoginView(router: .preview)` 처럼 쓰는 프리뷰용 라우터.
    static var preview: PreviewRouter { PreviewRouter() }
}
#endif
