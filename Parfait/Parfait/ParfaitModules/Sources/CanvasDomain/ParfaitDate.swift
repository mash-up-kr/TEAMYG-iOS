//
//  ParfaitDate.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 캔버스 하루를 가리키는 달력 날짜. 시각·타임존을 갖지 않는다 —
/// 서버의 `yyyy-MM-dd` 와 1:1 로 대응하며, 하루 경계(오전 3시) 판단은 화면 레이어가 한다.
public struct ParfaitDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
