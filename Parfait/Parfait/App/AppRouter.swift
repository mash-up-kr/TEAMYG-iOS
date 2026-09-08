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

    /// 푸시 탭 같은 외부 진입 — 루트는 그대로 두고 그 위 스택을 비운 뒤 목적지 하나만 남긴다.
    /// 목적지가 루트와 같으면 루트만 남는다.
    /// `push(_:)` 는 현재 스택을 못 보고 무조건 쌓아서 같은 화면이 두 장 겹친다
    /// (`NavigationPath` 는 내용 조회가 안 돼 "이미 그 화면인가" 검사가 불가) → 초기화 후 이동한다.
    func resetPath(to route: AppRoute) {
        path = NavigationPath()
        if route != rootRoute { path.append(route) }
    }
}
