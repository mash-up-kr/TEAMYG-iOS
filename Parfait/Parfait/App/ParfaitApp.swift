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
    init() {
        KakaoAuthConfigurator.initialize(
            appKey: Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String ?? ""
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    KakaoAuthConfigurator.handleOpenURL(url)
                }
        }
    }
}
