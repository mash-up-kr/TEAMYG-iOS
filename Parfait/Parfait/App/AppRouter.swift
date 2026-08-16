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

    /// `replaceStack(with:)` 가 지정한 새 루트 화면. `nil` 이면 초기 루트를 쓴다.
    private(set) var rootRoute: AppRoute?

    func push(_ route: AppRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }

    func replaceStack(with route: AppRoute) {
        rootRoute = route
        path = NavigationPath()
    }
}
