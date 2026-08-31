//
//  AppDelegate.swift
//  Parfait
//
//  Created by Enes on 8/31/26.
//

import FirebaseCore
import UIKit

// SwiftUI 라이프사이클에는 실제 UIApplicationDelegate 가 없어 Firebase(푸시 APNs 토큰
// 스위즐링 등)가 붙을 대상이 없다 → 어댑터로 부착. UIKit 혼용 사유는 이것뿐.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
