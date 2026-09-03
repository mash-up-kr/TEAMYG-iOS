//
//  CanvasStore+CalendarState.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/1/26.
//

import Foundation

public struct CalendarDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date) {
        let components = Self.gregorian.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 1
        month = components.month ?? 1
        day = components.day ?? 1
    }

    public init(canvasDayContaining date: Date) {
        let shiftedDate = Self.gregorian.date(byAdding: .hour, value: -Self.dayResetHour, to: date)
        self.init(date: shiftedDate ?? date)
    }

    public static var today: CalendarDate {
        CalendarDate(canvasDayContaining: .now)
    }

    static let dayResetHour = 3

    /// 이 캔버스 하루가 덮는 실제 시각 구간 (시작 포함·끝 제외).
    /// 기기 현지 시각 오전 3시가 경계다 (`canvas-policy.md` §4.1·§5.3).
    var timeInterval: DateInterval? {
        guard let midnight = date,
              let start = Self.gregorian.date(byAdding: .hour, value: Self.dayResetHour, to: midnight),
              let end = Self.gregorian.date(byAdding: .day, value: 1, to: start)
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    var date: Date? {
        Self.gregorian.date(from: DateComponents(year: year, month: month, day: day))
    }

    var monthName: String {
        guard Self.monthNames.indices.contains(month - 1) else { return "" }
        return Self.monthNames[month - 1]
    }

    /// `N월 N일` — 갤러리 저장 결과 Toast 문구에 쓴다 (`canvas-policy.md` §7.3).
    var koreanDateText: String {
        "\(month)월 \(day)일"
    }

    var weekdayName: String {
        guard let date else { return "" }
        let weekday = Self.gregorian.component(.weekday, from: date)
        return Self.gregorian.shortWeekdaySymbols[weekday - 1]
    }
}

public extension CanvasStore {
    struct CalendarState: Equatable, Sendable {
        public var selectedDate: CalendarDate
        public var recordedDates: Set<CalendarDate>
        public var recordedYears: Set<Int>
        public var today: CalendarDate
        public var presentation: CalendarPresentation
        public var exploredYear: Int
        public var exploredMonth: Int

        public init(
            selectedDate: CalendarDate? = nil,
            recordedDates: Set<CalendarDate> = [],
            recordedYears: Set<Int>? = nil,
            today: CalendarDate = .today,
            presentation: CalendarPresentation = .closed,
            exploredYear: Int? = nil,
            exploredMonth: Int? = nil
        ) {
            let resolvedSelectedDate = selectedDate ?? today
            self.selectedDate = resolvedSelectedDate
            self.recordedDates = recordedDates
            self.recordedYears = recordedYears ?? Set(recordedDates.map(\.year))
            self.today = today
            self.presentation = presentation
            self.exploredYear = exploredYear ?? resolvedSelectedDate.year
            self.exploredMonth = exploredMonth ?? resolvedSelectedDate.month
        }

        var dateText: String {
            "\(selectedDate.monthName) \(selectedDate.day)"
        }

        var weekdayText: String {
            "(\(selectedDate.weekdayName))"
        }

        var monthTitle: String {
            CalendarDate.monthNames[exploredMonth - 1]
        }

        var isDropdownOpen: Bool {
            presentation == .monthList || presentation == .yearList
        }

        var yearOptions: [CalendarOption] {
            recordedYears
                .filter { $0 <= today.year }
                .sorted()
                .map { year in
                    CalendarOption(
                        value: year,
                        title: String(year),
                        isSelected: exploredYear == year
                    )
                }
        }

        var monthOptions: [CalendarOption] {
            let recordedMonths = Set(
                recordedDates
                    .filter { date in
                        date.year == exploredYear && date <= today
                    }
                    .map(\.month)
            )

            return recordedMonths.sorted().map { month in
                CalendarOption(
                    value: month,
                    title: CalendarDate.monthNames[month - 1],
                    isSelected: exploredMonth == month
                )
            }
        }

        func contentState(for date: CalendarDate) -> ContentState {
            recordedDates.contains(date) ? .filled : .empty
        }

        var days: [CalendarDay] {
            guard
                let firstDate = CalendarDate(year: exploredYear, month: exploredMonth, day: 1).date,
                let dayRange = CalendarDate.gregorian.range(of: .day, in: .month, for: firstDate)
            else { return [] }

            let leadingCount = CalendarDate.gregorian.component(.weekday, from: firstDate) - 1
            let visibleCount = leadingCount + dayRange.count
            let trailingCount = (7 - visibleCount % 7) % 7
            let startDate = CalendarDate.gregorian.date(byAdding: .day, value: -leadingCount, to: firstDate)

            return (0..<(visibleCount + trailingCount)).compactMap { offset in
                guard
                    let startDate,
                    let date = CalendarDate.gregorian.date(byAdding: .day, value: offset, to: startDate)
                else { return nil }

                let calendarDate = CalendarDate(date: date)
                let hasRecord = recordedDates.contains(calendarDate)
                return CalendarDay(
                    date: calendarDate,
                    isInExploredMonth: calendarDate.year == exploredYear && calendarDate.month == exploredMonth,
                    hasRecord: hasRecord,
                    isEnabled: isSelectable(calendarDate),
                    isSelected: calendarDate == selectedDate,
                    isToday: calendarDate == today
                )
            }
        }

        mutating func toggle() {
            if presentation == .closed {
                exploredYear = selectedDate.year
                exploredMonth = selectedDate.month
                presentation = .grid
            } else {
                close()
            }
        }

        mutating func dismissTopPresentation() {
            switch presentation {
            case .monthList, .yearList:
                presentation = .grid
            case .grid:
                close()
            case .closed:
                break
            }
        }

        mutating func selectMonth(_ month: Int) {
            guard monthOptions.contains(where: { $0.value == month }) else { return }
            exploredMonth = month
            presentation = .grid
        }

        @discardableResult
        mutating func selectYear(_ year: Int) -> Bool {
            guard yearOptions.contains(where: { $0.value == year }) else { return false }
            exploredYear = year
            presentation = .grid
            return true
        }

        /// 연도 목록(`recordedYears`)은 연도 조회 API 가 소유한다 — 여기서 지우면
        /// 토핑이 없는 해를 탐색한 순간 그 해가 목록에서 사라져 되돌아갈 수 없다.
        /// 날짜 인디케이터만 `recordedDates` 로 판정한다.
        mutating func replaceRecordedDates(_ dates: Set<CalendarDate>, for year: Int) {
            recordedDates = recordedDates.filter { $0.year != year }
            recordedDates.formUnion(dates.filter { $0.year == year })
            recordedYears.insert(year)
        }

        @discardableResult
        mutating func updateToday(_ newToday: CalendarDate) -> Bool {
            guard newToday != today else { return false }

            let wasOnToday = selectedDate == today
            today = newToday
            guard wasOnToday else { return false }

            selectedDate = newToday
            exploredYear = newToday.year
            exploredMonth = newToday.month
            return true
        }

        @discardableResult
        mutating func selectDate(_ date: CalendarDate) -> Bool {
            guard isSelectable(date) else { return false }
            open(date)
            return true
        }

        /// 서버가 "완성됐다" 고 알려준 과거 캔버스(SY-001-New 안내 대상)를 연다.
        /// 그 날짜에 토핑이 0장이면 `recordedDates` 에 없어 `selectDate` 가 실패하는데,
        /// 배경만 바꾼 캔버스도 완성으로 취급하므로(`canvas-policy.md` §4.3) 막으면 안 된다.
        mutating func openKnownPastDate(_ date: CalendarDate) -> Bool {
            guard date <= today else { return false }
            recordedDates.insert(date)
            open(date)
            return true
        }

        private mutating func open(_ date: CalendarDate) {
            selectedDate = date
            close()
        }

        mutating func close() {
            presentation = .closed
            exploredYear = selectedDate.year
            exploredMonth = selectedDate.month
        }

        private func isSelectable(_ date: CalendarDate) -> Bool {
            date <= today && (date == today || recordedDates.contains(date))
        }
    }

    struct CalendarDay: Equatable, Identifiable, Sendable {
        public var id: CalendarDate { date }
        let date: CalendarDate
        let isInExploredMonth: Bool
        let hasRecord: Bool
        let isEnabled: Bool
        let isSelected: Bool
        let isToday: Bool
    }

    struct CalendarOption: Equatable, Identifiable, Sendable {
        public var id: Int { value }
        let value: Int
        let title: String
        let isSelected: Bool
    }

    enum CalendarPresentation: Equatable, Sendable {
        case closed
        case grid
        case monthList
        case yearList
    }
}
