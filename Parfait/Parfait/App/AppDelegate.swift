//
//  AppDelegate.swift
//  Parfait
//
//  Created by Enes on 8/31/26.
//

import FirebaseCore
import FirebaseMessaging
import Routing
import UIKit
import UserNotifications
import Common

// SwiftUI 라이프사이클에는 실제 UIApplicationDelegate 가 없어 Firebase(푸시 APNs 토큰
// 스위즐링 등)가 붙을 대상이 없다 → 어댑터로 부착. UIKit 혼용 사유는 이것뿐.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// 푸시 탭으로 들어온 이동 목적지 스트림 — RootView 가 구독해 화면을 전환한다.
    /// 콜드 스타트(뷰가 뜨기 전) 탭도 스트림이 버퍼링해 뒀다가 구독 시작 시 흘려보낸다.
    let notificationRoutes: AsyncStream<AppRoute>
    private let notificationRouteContinuation: AsyncStream<AppRoute>.Continuation

    override init() {
        (notificationRoutes, notificationRouteContinuation) = AsyncStream.makeStream()
        super.init()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // APNs 등록은 알림 권한과 무관하다 — 권한을 거부해도 APNs 토큰은 받아야
        // FCM 등록 토큰이 발급된다(스위즐링 OFF). 권한은 배너 표시만 결정한다.
        application.registerForRemoteNotifications()
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        }
        return true
    }

    /// 스위즐링을 껐으므로(Info.plist FirebaseAppDelegateProxyEnabled = NO)
    /// APNs 토큰 → FCM 전달을 여기서 직접 한다.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        YGLogger.log("APNs device token: \(deviceToken.map { String(format: "%02x", $0) }.joined())")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        YGLogger.error("APNs registration failed")
    }
}

extension AppDelegate: MessagingDelegate {
    // ponytail: 로그만 남긴다 — 서버 등록은 App 루트가 세션 생길 때 직접 조회해서 한다(RootView).
    // 세션 중 토큰이 로테이션되면 다음 실행·로그인에서 등록된다. 즉시 반영이 필요해지면 여기서 등록을 트리거할 것.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        YGLogger.log("FCM registration token: \(fcmToken ?? "nil")")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// 포그라운드 수신 — 시스템 배너로 그대로 보여준다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // 스위즐링 비활성 → FCM 전송 지표 보고를 직접 한다 (didReceive 도 동일).
        Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
        return [.banner, .list, .sound]
    }

    /// 푸시 탭 — 페이로드에 이동 목적지가 있으면 스트림으로 발행한다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        Messaging.messaging().appDidReceiveMessage(userInfo)
        YGLogger.log("푸시 탭 payload: \(userInfo)")
        if let route = AppRoute(pushUserInfo: userInfo) {
            notificationRouteContinuation.yield(route)
        }
    }
}

/// 푸시 페이로드 → 이동 목적지 계약. 서버가 FCM data 에 `route` 키로 목적지를,
/// 목적지별 부가 키를 담아 보낸다. 예: {"route": "canvas", "groupID": "42"} → 캔버스(C-001).
/// 모르는 값이면 nil — 화면 이동 없이 앱만 열린다.
private extension AppRoute {
    init?(pushUserInfo userInfo: [AnyHashable: Any]) {
        switch userInfo["route"] as? String {
        case "group":
            self = .group
        case "canvas":
            guard let groupID = userInfo["groupID"] as? String else { return nil }
            self = .canvas(groupID: groupID)
        default:
            return nil
        }
    }
}
