//
//  ParfaitApp.swift
//  Parfait
//
//  Created by Enes on 6/9/26.
//

import SwiftUI
import AuthData

@main
struct ParfaitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        KakaoAuthConfigurator.initialize(
            appKey: Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String ?? ""
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(notificationRoutes: appDelegate.notificationRoutes)
                .onOpenURL { url in
                    KakaoAuthConfigurator.handleOpenURL(url)
                }
        }
    }
}
