//
//  AlbumPolicy.swift
//  CanvasFeature
//
//  Created by 김남수 on 8/5/26.
//

import Foundation

/// 앨범 기능의 기획 정책 모음 — 값·규칙의 출처는 기획 스펙.
/// 다른 화면이 같은 "하루" 정의를 쓰게 되면 CanvasDomain 으로 올린다.
enum AlbumPolicy {
    /// 최근 업로드 섹션 최대 표시 개수.
    static let recentUploadsLimit = 9

    /// 정책상 "오늘" 창: 가장 최근 03:00 부터 24시간 (03:00 ~ 다음날 02:59:59).
    /// 기기 사진·최근 업로드 노출 필터가 공용으로 쓴다.
    static func todayWindow(now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        let todayThreeAM = calendar.date(bySettingHour: 3, minute: 0, second: 0, of: now) ?? now
        let start = now >= todayThreeAM
            ? todayThreeAM
            : (calendar.date(byAdding: .day, value: -1, to: todayThreeAM) ?? todayThreeAM)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }
}
