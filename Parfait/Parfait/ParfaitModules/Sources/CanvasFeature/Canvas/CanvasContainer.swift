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
    /// 캔버스 패널의 화면 좌표 — 텍스트 입력(C-106)이 같은 자리에 캔버스를 겹쳐 그린다.
    var onBoardFrameChange: (CGRect) -> Void = { _ in }

    /// 상단 안내를 위로 스와이프해 닫았는지 — 표시 수명은 뷰의 관심사라 Store 에 두지 않는다.
    @State private var isNudgeDismissed = false

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let contentSize = CGSize(
                    width: max(proxy.size.width - .padding7 * 2, 0),
                    height: max(proxy.size.height - .padding6 * 2, 0)
                )

                ScrollView {
                    VStack(spacing: -1) {
                        CanvasBoard(
                            dateText: state.dateText,
                            weekdayText: state.weekdayText,
                            contentState: state.contentState,
                            canvasContent: state.canvasContent,
                            spotlightedLayerID: state.spotlightedLayerID,
                            isDimmed: state.menuState == .sourceOptions,
                            onCalendarTap: { perform(.calendarTapped) },
                            onSaveTap: { perform(.savePreviewRequested) },
                            onToppingTap: { perform(.toppingTapped($0)) },
                            onTextTap: { perform(.textTapped($0)) },
                            onSpotlightDismiss: { perform(.spotlightDismissed) },
                            onDimTap: { perform(.menuDimTapped) },
                            onToppingImageLoaded: { send(.toppingImageLoaded($0)) },
                            onToppingImageLoadFailed: { send(.toppingImageLoadFailed($0)) }
                        )
                        .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .global)
                        } action: { frame in
                            onBoardFrameChange(frame)
                        }
                        .overlay(alignment: .bottom) {
                            if state.menuState == .sourceOptions {
                                CanvasMenuSourceOptions(
                                    onCameraOptionTap: { perform(.cameraOptionTapped) },
                                    onGalleryOptionTap: { perform(.galleryOptionTapped) },
                                    onTextOptionTap: {
                                        // 메뉴는 C-106 이 페이드인하는 동안 캔버스 위에서 같이 페이드아웃한다 — 한 번에 접으면
                                        // 메뉴 딤이 꺼져 밝아졌다가 C-106 딤으로 다시 어두워지며 번쩍였다.
                                        withAnimation(.easeInOut(duration: 0.2)) { perform(.menuDimTapped) }
                                        // 텍스트는 같은 캔버스 위에 바로 쓰는 동작이라 새 화면처럼 밀어 올리지 않는다 — C-106 이 직접 페이드인한다.
                                        var transaction = Transaction()
                                        transaction.disablesAnimations = true
                                        withTransaction(transaction) { perform(.textOptionTapped) }
                                    }
                                )
                            }
                        }

                        menuBar
                    }
                    .frame(width: CanvasArea.width(fitting: contentSize))
                    .frame(maxWidth: .infinity, minHeight: contentSize.height)
                    .padding(.horizontal, .padding7)
                    .padding(.vertical, .padding6)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always)
                .refreshable { perform(.refreshRequested) }
            }
            // 캘린더 레이어보다 아래에 두려고 ZStack 이 아니라 보드 쪽에 단다.
            .ygAlert(isPresented: isNudgePresented) { nudge }

            if state.calendar.presentation != .closed {
                calendarLayer
            }
        }
    }

    /// 상단 안내 — YGAlert 닫기 정책을 따른다 (위로 스와이프해야만 닫힘, 자동 닫힘 없음).
    /// 진입 안내가 SY-001-New 안내보다 먼저다.
    private var isNudgePresented: Binding<Bool> {
        Binding(
            get: { (state.entryNudge != nil || state.pastParfaitNudge != nil) && !isNudgeDismissed },
            set: { isPresented in
                if !isPresented { isNudgeDismissed = true }
            }
        )
    }

    /// 사용자 조작은 상단 안내를 닫고 보낸다 — 띄운 채 텍스트 입력(C-106) 등으로 넘어가면 안내가 화면 위에 걸려 잘린다.
    private func perform(_ intent: CanvasStore.Intent) {
        isNudgeDismissed = true
        send(intent)
    }

    @ViewBuilder
    private var nudge: some View {
        if let entryNudge = state.entryNudge {
            CanvasEntryNudge(nudge: entryNudge)
                .padding(.top, .padding6)
        } else if let pastParfaitNudge = state.pastParfaitNudge {
            CanvasPastParfaitNudge(nudge: pastParfaitNudge) {
                perform(.pastParfaitNudgeTapped)
            }
            .padding(.top, .padding6)
        }
    }

    @ViewBuilder
    private var menuBar: some View {
        if state.isClosedCanvas {
            CanvasClosedMenuBar(
                onTodayParfaitTap: { perform(.todayParfaitTapped) }
            )
        } else {
            CanvasMenuBar(
                isSourceOptionsPresented: state.menuState == .sourceOptions,
                onToppingAddTap: { perform(.toppingAddTapped) },
                onBackgroundEditTap: { perform(.backgroundEditTapped) }
            )
        }
    }

    private var calendarLayer: some View {
        ZStack(alignment: .top) {
            Button { perform(.calendarDimTapped) } label: {
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
                onMonthTap: { perform(.calendarMonthTapped) },
                onYearTap: { perform(.calendarYearTapped) },
                onMonthSelect: { perform(.calendarMonthSelected($0)) },
                onYearSelect: { perform(.calendarYearSelected($0)) },
                onDateSelect: { perform(.calendarDateSelected($0)) },
                onDropdownDismiss: { perform(.calendarDimTapped) }
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
    let spotlightedLayerID: CanvasLayer.LayerID?
    let isDimmed: Bool
    let onCalendarTap: () -> Void
    let onSaveTap: () -> Void
    let onToppingTap: (Int) -> Void
    let onTextTap: (Int) -> Void
    let onSpotlightDismiss: () -> Void
    let onDimTap: () -> Void
    let onToppingImageLoaded: (Int) -> Void
    let onToppingImageLoadFailed: (Int) -> Void

    var body: some View {
        ZStack {
            CanvasPanelShape()
                .fill(Color.gray100)

            Group {
                switch contentState {
                case .empty:
                    message("아직 캔버스가 비어 있어요", "첫번째 사진을 올려 캔버스를 채워보세요")

                case .failed:
                    message("캔버스를 불러오지 못했어요", "아래로 당겨 새로고침해 주세요")

                // 조회 중에는 전체 화면 로딩 딤(C-001-Loading)이 덮고 있어 보드에는 아무것도 그리지 않는다.
                case .loading:
                    Color.clear

                case .filled:
                    if let canvasContent {
                        CanvasContentView(
                            content: canvasContent,
                            spotlightedLayerID: spotlightedLayerID,
                            onImageTap: { onToppingTap($0.id) },
                            onTextTap: { onTextTap($0.id) },
                            onDimTap: onSpotlightDismiss,
                            onToppingImageLoaded: onToppingImageLoaded,
                            onToppingImageLoadFailed: onToppingImageLoadFailed
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
                    onCalendarTap: onCalendarTap,
                    onSaveTap: onSaveTap
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

/// 캔버스 위에 얹히는 날짜 바(`Bar-Canvas`).
///
/// 왼쪽은 캘린더 아이콘·날짜(탭하면 캘린더), 오른쪽 끝은 저장 미리보기로 가는 `Ic_Save`.
struct CanvasDateHeader: View {
    static let height: CGFloat = 44

    let dateText: String
    let weekdayText: String
    let onCalendarTap: () -> Void
    let onSaveTap: () -> Void

    var body: some View {
        HStack(spacing: .gap1) {
            Button(action: onCalendarTap) {
                HStack(spacing: .gap2) {
                    Image.icCalendar
                        .resizable()
                        .frame(width: 16, height: 16)
                        .frame(width: 24, height: 24)
                        .contentShape(.rect)
                        .foregroundStyle(.gray500)
                    HStack(spacing: .gap1) {
                        Text(dateText)
                            .foregroundStyle(.gray800)
                        Text(weekdayText)
                            .foregroundStyle(.gray300)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            YGIconButton(.icSave, size: .small, tone: .strong, action: onSaveTap)
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

struct CanvasPanelShape: Shape {
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
