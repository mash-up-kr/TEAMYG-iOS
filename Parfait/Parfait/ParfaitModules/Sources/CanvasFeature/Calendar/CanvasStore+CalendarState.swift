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

        mutating func replaceRecordedDates(_ dates: Set<CalendarDate>, for year: Int) {
            recordedDates = recordedDates.filter { $0.year != year }
            recordedDates.formUnion(dates.filter { $0.year == year })

            if dates.contains(where: { $0.year == year }) {
                recordedYears.insert(year)
            } else {
                recordedYears.remove(year)
            }
        }

        @discardableResult
        mutating func selectDate(_ date: CalendarDate) -> Bool {
            guard isSelectable(date) else { return false }
            selectedDate = date
            close()
            return true
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
