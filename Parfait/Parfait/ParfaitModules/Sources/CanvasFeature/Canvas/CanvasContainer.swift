//
//  CanvasContainer.swift
//  CanvasFeature
//
//  Created by 박서연 on 7/30/26.
//

import SwiftUI
import UIComponent

struct CanvasContainer: View {
    let state: CanvasStore.State
    let send: (CanvasStore.Intent) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                VStack(spacing: -1) {
                    CanvasBoard(
                        dateText: state.dateText,
                        weekdayText: state.weekdayText,
                        contentState: state.contentState,
                        canvasContent: state.canvasContent,
                        isDimmed: state.menuState == .sourceOptions,
                        onCalendarTap: { send(.calendarTapped) }
                    )
                    .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)
                    .overlay(alignment: .bottom) {
                        if state.menuState == .sourceOptions {
                            CanvasMenuSourceOptions(
                                onCameraOptionTap: { send(.cameraOptionTapped) },
                                onGalleryOptionTap: { send(.galleryOptionTapped) }
                            )
                        }
                    }

                    CanvasMenuBar(
                        onToppingAddTap: { send(.toppingAddTapped) },
                        onCanvasEditTap: { send(.canvasEditTapped) }
                    )
                }
                .frame(width: CanvasArea.width(fitting: proxy.size))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, .padding7)
            .padding(.vertical, .padding6)

            if state.calendar.presentation != .closed {
                calendarLayer
            }
        }
    }

    private var calendarLayer: some View {
        ZStack(alignment: .top) {
            Button { send(.calendarDimTapped) } label: {
                Color.clear
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .overlay {
                Color.gray500
                    .padding(.horizontal, .padding7)
                    .padding(.bottom, .padding6)
                    .allowsHitTesting(false)
            }

            CanvasCalendar(
                state: state.calendar,
                onMonthTap: { send(.calendarMonthTapped) },
                onYearTap: { send(.calendarYearTapped) },
                onMonthSelect: { send(.calendarMonthSelected($0)) },
                onYearSelect: { send(.calendarYearSelected($0)) },
                onDateSelect: { send(.calendarDateSelected($0)) },
                onDropdownDismiss: { send(.calendarDimTapped) }
            )
            .padding(.horizontal, .padding7 + 1)
        }
        .padding(.top, .padding6 + 44)
    }
}

private struct CanvasBoard: View {
    let dateText: String
    let weekdayText: String
    let contentState: CanvasStore.ContentState
    let canvasContent: CanvasStore.CanvasContent?
    let isDimmed: Bool
    let onCalendarTap: () -> Void

    var body: some View {
        ZStack {
            CanvasPanelShape()
                .fill(Color.gray100)

            Group {
                switch contentState {
                case .empty:
                    VStack(spacing: 0) {
                        Text("아직 캔버스가 비어 있어요")
                        Text("첫번째 토핑을 올려 캔버스를 채워보세요")
                    }
                    .suit(.caption01Medium)
                    .foregroundStyle(.gray500)
                    .multilineTextAlignment(.center)
                    .padding(.top, 44)

                case .loading:
                    ProgressView()
                        .tint(.gray500)
                        .padding(.top, 44)

                case .filled:
                    if let canvasContent {
                        CanvasContentView(content: canvasContent)
                    } else {
                        Color.clear
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                CanvasDateHeader(
                    dateText: dateText,
                    weekdayText: weekdayText,
                    onCalendarTap: onCalendarTap
                )

                Spacer(minLength: 0)
            }

            if isDimmed {
                CanvasPanelShape()
                    .fill(Color.gray500)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(CanvasPanelShape())
        .overlay {
            CanvasPanelShape()
                .stroke(Color.gray500, lineWidth: 1)
        }
    }
}

struct CanvasDateHeader: View {
    let dateText: String
    let weekdayText: String
    let onCalendarTap: () -> Void

    var body: some View {
        HStack(spacing: .gap1) {
            Text(dateText)
                .foregroundStyle(.gray800)
            Text(weekdayText)
                .foregroundStyle(.gray300)

            Spacer()

            Button(action: onCalendarTap) {
                Image.icCalendar
                    .frame(width: 16, height: 16)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .suit(.body02Regular)
        .padding(.leading, .padding6)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(.white75)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.gray500)
                .frame(height: 1)
        }
    }
}

private struct CanvasPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cutLength = min(17, min(rect.width, rect.height))

        path.move(to: CGPoint(x: cutLength, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: cutLength))
        path.closeSubpath()

        return path
    }
}

#Preview("Empty") {
    CanvasContainer(
        state: .init(),
        send: { _ in }
    )
}

#Preview("Edit options") {
    CanvasContainer(
        state: .init(
            contentState: .filled,
            canvasContent: .init(background: .color(hex: "#FFDDE5")),
            menuState: .sourceOptions
        ),
        send: { _ in }
    )
}

#Preview("Calendar") {
    let today = CalendarDate(year: 2026, month: 8, day: 5)

    CanvasContainer(
        state: .init(
            calendar: .init(
                recordedDates: [
                    .init(year: 2026, month: 8, day: 1),
                    .init(year: 2026, month: 8, day: 2)
                ],
                today: today,
                presentation: .grid
            )
        ),
        send: { _ in }
    )
}
