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
    ///
    /// 하루 경계는 `CalendarDate` 가 소유한다 — 캘린더가 보는 "오늘" 과 갤러리가 보는 "오늘" 이
    /// 갈리지 않도록 경계 계산을 한곳에서만 한다 (`canvas-policy.md` §4.1·§5.3).
    static func todayWindow(now: Date = .now) -> DateInterval {
        let today = CalendarDate(canvasDayContaining: now)
        guard let window = today.timeInterval else {
            return DateInterval(start: now, duration: 86_400)
        }
        return window
    }
}
