//
//  ReviewRequestPolicy.swift
//  Parfait
//
//  Created by 김남수 on 11/23/26.
//

import Foundation

/// 앱 리뷰 요청 노출 조건 (#165).
/// 업로드(배경·텍스트·사진 구분 없이) 3회 이상 + 첫 로그인 후 3일 경과 시 요청하고,
/// 이후엔 4개월마다 다시 요청한다.
///
/// 시스템 리뷰 팝업은 사용자가 거절했는지 알려주지 않는다 → "띄운 시점"만 기록해 4개월을 센다.
/// 이미 리뷰를 쓴 사용자에겐 애플이 알아서 다시 띄우지 않는다.
/// 기기 단위 기록이다 — 로그아웃·계정 전환해도 초기화하지 않는다.
struct ReviewRequestPolicy: Sendable {
    private static let requiredUploadCount = 3
    private static let firstLoginDateKey = "reviewRequest.firstLoginDate"
    private static let uploadCountKey = "reviewRequest.uploadCount"
    private static let lastRequestDateKey = "reviewRequest.lastRequestDate"

    // UserDefaults 는 Sendable 이 아니라 보관하지 않고 그때그때 꺼낸다(스레드 안전함은 문서 보장).
    private var defaults: UserDefaults { .standard }
    private let calendar = Calendar(identifier: .gregorian)

    /// 세션이 생길 때마다 불러도 된다 — 최초 1회만 기록한다.
    func recordLogin(now: Date = .now) {
        guard defaults.object(forKey: Self.firstLoginDateKey) == nil else { return }
        defaults.set(now, forKey: Self.firstLoginDateKey)
    }

    /// 업로드 성공을 기록하고, 지금 리뷰를 요청할 차례면 `true` (요청 시점도 함께 기록한다).
    func recordUpload(now: Date = .now) -> Bool {
        let uploadCount = defaults.integer(forKey: Self.uploadCountKey) + 1
        defaults.set(uploadCount, forKey: Self.uploadCountKey)

        guard uploadCount >= Self.requiredUploadCount,
              let firstLoginDate = defaults.object(forKey: Self.firstLoginDateKey) as? Date,
              let loginEligibleDate = calendar.date(byAdding: .day, value: 3, to: firstLoginDate),
              loginEligibleDate <= now else {
            return false
        }
        if let lastRequestDate = defaults.object(forKey: Self.lastRequestDateKey) as? Date {
            guard let nextRequestDate = calendar.date(byAdding: .month, value: 4, to: lastRequestDate),
                  nextRequestDate <= now else {
                return false
            }
        }
        defaults.set(now, forKey: Self.lastRequestDateKey)
        return true
    }
}
