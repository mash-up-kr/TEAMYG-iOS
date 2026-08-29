//
//  AppRouter.swift
//  Parfait
//
//  Created by Enes on 6/25/26.
//

import SwiftUI
import Routing

@MainActor @Observable
final class AppRouter: Router {
    var path = NavigationPath()

    /// 스택의 루트 화면. 최초 진입은 로그인이고, `replaceStack(with:)` 가 교체한다.
    private(set) var rootRoute: AppRoute = .login

    func push(_ route: AppRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }

    func replaceStack(with route: AppRoute) {
        rootRoute = route
        path = NavigationPath()
    }
}
