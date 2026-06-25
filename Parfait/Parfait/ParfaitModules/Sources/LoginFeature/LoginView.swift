import SwiftUI
import Routing

//  로그인 화면. 라우팅은 주입받은 Router 로 트리거한다(피처 내 라우팅).
//  GroupFeature/CanvasFeature 를 import 하지 않는다 — AppRoute 만 안다.
//  TODO: Store(MVIStore) + State/Intent 추가, body 구현.
public struct LoginView: View {
    private let router: Router

    public init(router: Router) {
        self.router = router
    }

    public var body: some View {
        Button("그룹으로 →") {
            router.push(.group)
        }
    }
}
