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

    /// 정책상 "오늘" 창: 가장 최근 03:00 부터 24시간 (03:00 ~ 다음날 02:59:59).
    /// 기기 사진·최근 업로드 노출 필터가 공용으로 쓴다.
    static func todayWindow(now: Date = .now) -> DateInterval {
        let today = CalendarDate(canvasDayContaining: now)
        guard let window = today.timeInterval else {
            return DateInterval(start: now, duration: 86_400)
        }
        return window
    }
}
