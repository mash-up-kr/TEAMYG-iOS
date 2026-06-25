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
    
    func push(_ route: AppRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
}
