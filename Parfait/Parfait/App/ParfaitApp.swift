//
//  ParfaitApp.swift
//  Parfait
//
//  Created by Enes on 6/9/26.
//

import SwiftUI
import SwiftData
import AuthData

@main
struct ParfaitApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema()
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
        .modelContainer(sharedModelContainer)
    }
}
