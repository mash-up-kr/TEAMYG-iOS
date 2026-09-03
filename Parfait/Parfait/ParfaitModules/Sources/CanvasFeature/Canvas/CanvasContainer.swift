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
                // Pull-to-Refresh 를 걸기 위한 스크롤 컨테이너. 내용 높이를 뷰포트에 맞춰
                // 실제 스크롤은 일어나지 않고 당겨서 새로고침만 동작한다
                // (`canvas-policy.md` §4.2 — 다른 그룹원의 토핑을 받아오는 유일한 경로).
                ScrollView {
                    VStack(spacing: -1) {
                        CanvasBoard(
                            dateText: state.dateText,
                            weekdayText: state.weekdayText,
                            contentState: state.contentState,
                            canvasContent: state.canvasContent,
                            spotlightedToppingID: state.spotlightedToppingID,
                            isDimmed: state.menuState == .sourceOptions,
                            onCalendarTap: { send(.calendarTapped) },
                            onToppingTap: { send(.toppingTapped($0)) },
                            onSpotlightDismiss: { send(.spotlightDismissed) },
                            onDimTap: { send(.menuDimTapped) }
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

                        menuBar
                    }
                    .frame(width: CanvasArea.width(fitting: proxy.size))
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always)
                .refreshable { send(.refreshRequested) }
            }
            .padding(.horizontal, .padding7)
            .padding(.vertical, .padding6)

            if let pastParfaitNudge = state.pastParfaitNudge {
                CanvasPastParfaitNudge(nudge: pastParfaitNudge) {
                    send(.pastParfaitNudgeTapped)
                }
                .padding(.top, .padding6)
            }

            if state.calendar.presentation != .closed {
                calendarLayer
            }
        }
    }

    /// 과거 캔버스는 열람 전용이라 토핑 추가·캔버스 편집 대신 저장·오늘 가기를 제공한다 (`canvas-policy.md` §7.2).
    @ViewBuilder
    private var menuBar: some View {
        if state.isClosedCanvas {
            CanvasClosedMenuBar(
                onSaveToGalleryTap: { send(.saveToGalleryTapped) },
                onTodayParfaitTap: { send(.todayParfaitTapped) }
            )
        } else {
            CanvasMenuBar(
                onToppingAddTap: { send(.toppingAddTapped) },
                onCanvasEditTap: { send(.canvasEditTapped) }
            )
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
                Color.black25
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
        .padding(.top, .padding6 + CanvasDateHeader.height)
    }
}

private struct CanvasBoard: View {
    let dateText: String
    let weekdayText: String
    let contentState: CanvasStore.ContentState
    let canvasContent: CanvasStore.CanvasContent?
    let spotlightedToppingID: Int?
    let isDimmed: Bool
    let onCalendarTap: () -> Void
    let onToppingTap: (Int) -> Void
    let onSpotlightDismiss: () -> Void
    let onDimTap: () -> Void

    var body: some View {
        ZStack {
            CanvasPanelShape()
                .fill(Color.gray100)

            Group {
                switch contentState {
                case .empty:
                    message("아직 캔버스가 비어 있어요", "첫번째 토핑을 올려 캔버스를 채워보세요")

                // 네트워크 실패를 빈 캔버스로 보여주면 "우리 캔버스가 비었다" 고 오해한다.
                // 전용 시안이 없어(`canvas-policy.md` §8) 문구만 구분하고 재시도는 Pull-to-Refresh 로 받는다.
                case .failed:
                    message("캔버스를 불러오지 못했어요", "아래로 당겨 새로고침해 주세요")

                case .loading:
                    ProgressView()
                        .tint(.gray500)
                        .padding(.top, CanvasDateHeader.height)

                case .filled:
                    if let canvasContent {
                        CanvasContentView(
                            content: canvasContent,
                            spotlightedToppingID: spotlightedToppingID,
                            onImageTap: { onToppingTap($0.id) },
                            onDimTap: onSpotlightDismiss
                        )
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
                Button(action: onDimTap) {
                    CanvasPanelShape()
                        .fill(Color.black25)
                        .contentShape(CanvasPanelShape())
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(CanvasPanelShape())
        .overlay {
            CanvasPanelShape()
                .stroke(Color.gray500, lineWidth: 1)
        }
    }

    private func message(_ title: String, _ description: String) -> some View {
        VStack(spacing: 0) {
            Text(title)
            Text(description)
        }
        .suit(.caption01Medium)
        .foregroundStyle(.gray500)
        .multilineTextAlignment(.center)
        .padding(.top, CanvasDateHeader.height)
    }
}

struct CanvasDateHeader: View {
    static let height: CGFloat = 44

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
        .frame(height: Self.height)
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

#Preview("SY-001-Closed") {
    let today = CalendarDate(year: 2026, month: 8, day: 26)
    let pastDate = CalendarDate(year: 2026, month: 5, day: 20)

    CanvasContainer(
        state: .init(
            contentState: .filled,
            canvasContent: .init(background: .color(hex: "#FFDDE5")),
            calendar: .init(
                selectedDate: pastDate,
                recordedDates: [pastDate],
                today: today
            )
        ),
        send: { _ in }
    )
}
