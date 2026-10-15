//
//  AlbumPolicy.swift
//  CanvasFeature
//
//  Created by 김남수 on 8/5/26.
//

import Foundation

/// 앨범 기능의 기획 정책 모음 — 값·규칙의 출처는 기획 스펙.
enum AlbumPolicy {
    /// 최근 업로드 섹션 최대 표시 개수.
    static let recentUploadsLimit = 9

    /// 정책상 "오늘" 창: 그날 00:00 ~ 23:59:59.
    /// 기기 사진·최근 업로드 노출 필터가 공용으로 쓴다.
    static func todayWindow(now: Date = .now) -> DateInterval {
        dayWindow(containing: now)
    }

    /// `date` 가 속한 달력 하루(00:00 ~ 23:59:59).
    static func dayWindow(containing date: Date) -> DateInterval {
        CalendarDate.gregorian.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
    }
}
