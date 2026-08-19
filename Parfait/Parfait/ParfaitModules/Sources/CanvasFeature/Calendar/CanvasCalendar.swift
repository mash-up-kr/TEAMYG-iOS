//
//  CanvasCalendar.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/1/26.
//

import SwiftUI
import UIComponent

struct CanvasCalendar: View {
    let state: CanvasStore.CalendarState
    let onMonthTap: () -> Void
    let onYearTap: () -> Void
    let onMonthSelect: (Int) -> Void
    let onYearSelect: (Int) -> Void
    let onDateSelect: (CalendarDate) -> Void
    let onDropdownDismiss: () -> Void

    var body: some View {
        VStack(spacing: .gap2) {
            CanvasCalendarHeader(
                state: state,
                onMonthTap: onMonthTap,
                onYearTap: onYearTap,
                onDropdownDismiss: onDropdownDismiss
            )
            .padding(.horizontal, .padding6)

            CanvasCalendarGrid(
                days: state.days,
                onDateSelect: onDateSelect
            )
            .padding(.horizontal, .padding6)
            .overlay {
                CanvasDropdownDismissLayer(isActive: state.isDropdownOpen, action: onDropdownDismiss)
            }
            .overlay(alignment: .topLeading) {
                switch state.presentation {
                case .monthList:
                    CanvasCalendarDropdown(options: state.monthOptions, onSelect: onMonthSelect)
                        .padding(.leading, .padding6)
                case .yearList:
                    CanvasCalendarDropdown(options: state.yearOptions, onSelect: onYearSelect)
                        .padding(.leading, 104)
                case .closed, .grid:
                    EmptyView()
                }
            }
        }
        .padding(.top, .padding3)
        .padding(.bottom, .padding5)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.whiteFixed)
    }
}

private struct CanvasCalendarHeader: View {
    let state: CanvasStore.CalendarState
    let onMonthTap: () -> Void
    let onYearTap: () -> Void
    let onDropdownDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            CanvasCalendarHeaderButton(
                title: state.monthTitle,
                action: onMonthTap
            )

            CanvasCalendarHeaderButton(
                title: String(state.exploredYear),
                action: onYearTap
            )

            Spacer(minLength: 0)
        }
        .background {
            CanvasDropdownDismissLayer(isActive: state.isDropdownOpen, action: onDropdownDismiss)
        }
        .padding(.horizontal, .padding3)
        .frame(height: 44)
        .zIndex(1)
    }
}

private struct CanvasDropdownDismissLayer: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        if isActive {
            Button(action: action) {
                Color.clear
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CanvasCalendarHeaderButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .suit(.body02SemiBold)
                    .foregroundStyle(.gray900)

                Image.icCaretBottom
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(.gray300)
                    .frame(width: 24, height: 24)
                    .frame(width: 44, height: 44)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct CanvasCalendarDropdown: View {
    let options: [CanvasStore.CalendarOption]
    let onSelect: (Int) -> Void

    private var isScrollable: Bool {
        options.count > 5
    }

    private var visibleHeight: CGFloat {
        CGFloat(min(options.count, 5)) * 44
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(options) { option in
                    Button {
                        onSelect(option.value)
                    } label: {
                        Text(option.title)
                            .suit(.body02Regular)
                            .foregroundStyle(.gray700)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .background(option.isSelected ? Color.gray100 : .whiteFixed)
                    .overlay {
                        Rectangle()
                            .strokeBorder(Color.gray500, lineWidth: 1)
                    }
                }
            }
        }
        .scrollDisabled(!isScrollable)
        .scrollIndicators(isScrollable ? .visible : .hidden)
        .frame(width: 120, height: visibleHeight, alignment: .top)
        .background(.whiteFixed)
        .clipped()
    }
}

private struct CanvasCalendarGrid: View {
    let days: [CanvasStore.CalendarDay]
    let onDateSelect: (CalendarDate) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(spacing: .gap4) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .suit(.body02Regular)
                        .foregroundStyle(.gray400)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }

            LazyVGrid(columns: columns, spacing: .gap4) {
                ForEach(days) { day in
                    CanvasCalendarDateButton(day: day) {
                        onDateSelect(day.date)
                    }
                }
            }
        }
    }
}

private struct CanvasCalendarDateButton: View {
    let day: CanvasStore.CalendarDay
    let action: () -> Void

    var body: some View {
        VStack(spacing: .gap1) {
            Button(action: action) {
                dateLabel
                    .frame(width: 32, height: 32)
                    .background {
                        if day.isSelected {
                            Circle().fill(Color.gray900)
                        }
                    }
                    .overlay {
                        if day.isToday && !day.isSelected {
                            Circle().strokeBorder(Color.gray850, lineWidth: 1)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!day.isEnabled)

            Circle()
                .fill(day.hasRecord ? Color.cherry : .clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var dateLabel: some View {
        Text(String(day.date.day))
            .suit(day.isSelected ? .body02SemiBold : .body02Regular)
            .foregroundStyle(textColor)
    }

    private var textColor: Color {
        if day.isSelected { return .whiteFixed }
        return day.isEnabled ? .gray800 : .gray400
    }

}

#Preview("Calendar") {
    let today = CalendarDate(year: 2030, month: 5, day: 6)
    let selectedDate = CalendarDate(year: 2030, month: 5, day: 5)

    CanvasCalendar(
        state: .init(
            selectedDate: selectedDate,
            recordedDates: [
                .init(year: 2026, month: 5, day: 1),
                .init(year: 2037, month: 5, day: 2),
                .init(year: 2030, month: 4, day: 28),
                .init(year: 2030, month: 4, day: 29),
                .init(year: 2030, month: 5, day: 1),
                .init(year: 2030, month: 5, day: 2),
                selectedDate
            ],
            today: today,
            presentation: .grid
        ),
        onMonthTap: {},
        onYearTap: {},
        onMonthSelect: { _ in },
        onYearSelect: { _ in },
        onDateSelect: { _ in },
        onDropdownDismiss: {}
    )
    .frame(width: 335)
    .padding()
    .background(.gray100)
}
