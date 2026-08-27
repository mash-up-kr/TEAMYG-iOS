//
//  CanvasStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 7/30/26.
//

import CanvasDomain
import Foundation
import Observation
import UIComponent

@Observable @MainActor
public final class CanvasStore: MVIStore {
    public private(set) var state: State

    /// 토스트처럼 한 번만 소비해야 하는 결과는 화면 상태와 분리한다 (`docs/mvi.md`).
    @ObservationIgnored private let eventChannel = EventChannel<Event>()

    private let dependencies: Dependencies
    private var canvasLoadTask: Task<Void, Never>?
    private var gallerySaveTask: Task<Void, Never>?
    private var recordedDatesLoadTask: Task<Void, Never>?
    private var recordedYearsLoadTask: Task<Void, Never>?
    private var didLoadInitialData = false
    /// 과거 캔버스는 `parfaitID` 로만 조회할 수 있다. 목록 응답에서 받은 매핑을 들고 있는다.
    private var parfaitIDsByDate: [CalendarDate: Int] = [:]

    public init(
        state: State = State(),
        dependencies: Dependencies
    ) {
        self.state = state
        self.dependencies = dependencies
    }

    /// 화면이 사라졌다 다시 나타나도 이어 받을 수 있도록 구독마다 새 스트림을 내준다.
    func eventStream() -> AsyncStream<Event> {
        eventChannel.stream()
    }

    /// 토핑 추가 흐름이 저장 대상 캔버스를 지정할 때 쓴다.
    public var groupID: Int { dependencies.groupID }
    /// 캔버스 하위 편집 Store 조립에 같은 UseCase 인스턴스를 전달한다.
    var canvasUseCase: any CanvasUseCase { dependencies.canvasUseCase }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            state.calendar.updateToday(CalendarDate(canvasDayContaining: dependencies.now()))
            loadInitialDataIfNeeded()

        case .sceneBecameActive:
            reloadIfDayChanged()

        case .screenDisappeared:
            cancelTasks()

        case .canvasEditTapped,
             .canvasEditFlowDismissed,
             .canvasEditSaved:
            handleCanvasEditIntent(intent)

        case .toppingAddTapped,
             .cameraOptionTapped,
             .galleryOptionTapped,
             .toppingAddFlowDismissed,
             .toppingSaved:
            handleToppingAddIntent(intent)

        case .calendarTapped,
             .calendarDimTapped,
             .calendarMonthTapped,
             .calendarYearTapped,
             .calendarMonthSelected,
             .calendarYearSelected,
             .calendarDateSelected:
            handleCalendarIntent(intent)

        case .saveToGalleryTapped:
            saveCanvasToGallery()

        case .todayParfaitTapped:
            openTodayCanvas()

        case .moreMenuTapped:
            // 후속 화면 정책 확정 전까지 외형과 Intent 경계만 제공한다.
            break
        }
    }

    /// 과거 캔버스에서는 토핑을 올릴 수 없다 (`canvas-policy.md` §7.2).
    private func handleToppingAddIntent(_ intent: Intent) {
        switch intent {
        case .toppingAddTapped:
            guard !state.isClosedCanvas else { return }
            state.calendar.close()
            guard state.parfaitID != nil else {
                eventChannel.send(.canvasNotReady)
                return
            }
            state.menuState = state.menuState == .collapsed ? .sourceOptions : .collapsed

        case .cameraOptionTapped:
            openToppingAddFlow { .camera(canvasDate: $0) }

        case .galleryOptionTapped:
            openToppingAddFlow { .gallery(canvasDate: $0) }

        case .toppingAddFlowDismissed:
            state.toppingAddSource = nil

        case .toppingSaved:
            state.toppingAddSource = nil
            loadCanvas(for: state.calendar.selectedDate)

        default:
            break
        }
    }

    /// 토핑을 올릴 대상은 언제나 오늘 캔버스다 (`canvas-policy.md` §4.1).
    private func openToppingAddFlow(_ makeSource: (CalendarDate) -> ToppingAddSource) {
        guard !state.isClosedCanvas, state.parfaitID != nil else { return }
        state.calendar.close()
        state.menuState = .collapsed
        state.toppingAddSource = makeSource(CalendarDate(canvasDayContaining: dependencies.now()))
    }

    private func handleCalendarIntent(_ intent: Intent) {
        switch intent {
        case .calendarTapped:
            state.menuState = .collapsed
            state.calendar.toggle()
        case .calendarDimTapped:
            state.calendar.dismissTopPresentation()
        case .calendarMonthTapped:
            state.calendar.presentation = .monthList
        case .calendarYearTapped:
            state.calendar.presentation = .yearList
        case .calendarMonthSelected(let month):
            state.calendar.selectMonth(month)
        case .calendarYearSelected(let year):
            if state.calendar.selectYear(year) {
                loadRecordedDates(for: year)
            }
        case .calendarDateSelected(let date):
            if state.calendar.selectDate(date) {
                loadCanvas(for: date)
            }
        default:
            break
        }
    }

    private func handleCanvasEditIntent(_ intent: Intent) {
        switch intent {
        case .canvasEditTapped:
            guard !state.isClosedCanvas else { return }
            state.calendar.close()
            state.menuState = .collapsed
            guard state.parfaitID != nil else {
                eventChannel.send(.canvasNotReady)
                return
            }
            state.canvasEditDestination = .background
        case .canvasEditFlowDismissed:
            state.canvasEditDestination = nil
        case .canvasEditSaved:
            state.canvasEditDestination = nil
            loadCanvas(for: state.calendar.selectedDate)
        default:
            break
        }
    }

    /// SY-001-Closed `오늘의 파르페 가기` — 같은 화면에서 오늘 캔버스로 되돌린다.
    private func openTodayCanvas() {
        state.menuState = .collapsed
        guard state.calendar.selectDate(state.calendar.today) else { return }
        loadCanvas(for: state.calendar.today)
    }

    /// SY-001-Closed `갤러리에 저장` — 캔버스를 한 장으로 합성해 기기 사진 앨범에 저장한다.
    /// 권한 거부 전용 화면은 정책 범위 밖이라(`canvas-policy.md` §8) 거부도 실패 Toast 로 수렴한다.
    private func saveCanvasToGallery() {
        guard state.gallerySave != .saving else { return }
        state.calendar.close()

        guard let canvasContent = state.canvasContent else {
            eventChannel.send(.gallerySaveFailed)
            return
        }

        state.gallerySave = .saving
        let savedDate = state.calendar.selectedDate
        gallerySaveTask = Task { [weak self, dependencies] in
            var isSaved = false
            if let canvasImage = await dependencies.canvasImageExporter.image(of: canvasContent) {
                isSaved = await CanvasGallerySaver.save(canvasImage)
            }

            guard !Task.isCancelled, let self else { return }
            state.gallerySave = .idle
            eventChannel.send(
                isSaved ? .gallerySaveSucceeded(dateText: savedDate.koreanDateText) : .gallerySaveFailed
            )
        }
    }

    private func reloadIfDayChanged() {
        let today = CalendarDate(canvasDayContaining: dependencies.now())
        guard today != state.calendar.today else { return }

        let didFollowToday = state.calendar.updateToday(today)
        loadRecordedDates(for: today.year)
        guard didFollowToday else { return }
        loadCanvas(for: today)
    }

    private func loadCanvas(for date: CalendarDate) {
        canvasLoadTask?.cancel()

        state.contentState = .loading
        state.canvasContent = nil

        let parfaitID = date == state.calendar.today ? nil : parfaitIDsByDate[date]
        canvasLoadTask = Task { [weak self, dependencies] in
            do {
                let parfait = try await Self.fetchParfait(parfaitID: parfaitID, dependencies: dependencies)
                guard !Task.isCancelled, let self else { return }
                apply(parfait)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                state.contentState = .failed
            }
        }
    }

    /// 오늘은 전용 조회를, 과거는 목록에서 받아 둔 `parfaitID` 를 쓴다.
    private static func fetchParfait(
        parfaitID: Int?,
        dependencies: Dependencies
    ) async throws -> Parfait {
        guard let parfaitID else {
            return try await dependencies.canvasUseCase.fetchToday(groupID: dependencies.groupID)
        }
        return try await dependencies.canvasUseCase.fetchParfait(
            groupID: dependencies.groupID,
            parfaitID: parfaitID
        )
    }

    private func apply(_ parfait: Parfait) {
        state.parfaitID = parfait.id
        state.status = parfait.status
        state.lastClosedDate = parfait.lastClosedDate.map(CalendarDate.init)
        state.members = parfait.members.map(Member.init)
        parfaitIDsByDate[CalendarDate(parfait.date)] = parfait.id

        guard !parfait.isEmpty else {
            state.contentState = .empty
            state.canvasContent = nil
            return
        }
        state.contentState = .filled
        state.canvasContent = CanvasContent(parfait)
    }

    private func loadInitialDataIfNeeded() {
        guard !didLoadInitialData else { return }
        didLoadInitialData = true

        let selectedDate = state.calendar.selectedDate
        loadCanvas(for: selectedDate)
        loadRecordedDates(for: selectedDate.year)

        recordedYearsLoadTask = Task { [weak self, dependencies] in
            let years = try? await dependencies.canvasUseCase.fetchYears(groupID: dependencies.groupID)
            guard !Task.isCancelled, let self, let years else { return }
            state.calendar.recordedYears = Set(years)
        }
    }

    private func loadRecordedDates(for year: Int) {
        recordedDatesLoadTask?.cancel()
        recordedDatesLoadTask = Task { [weak self, dependencies] in
            let summaries = try? await dependencies.canvasUseCase.fetchSummaries(
                groupID: dependencies.groupID,
                year: year
            )
            guard !Task.isCancelled, let self, let summaries else { return }

            for summary in summaries {
                parfaitIDsByDate[CalendarDate(summary.date)] = summary.id
            }
            state.calendar.replaceRecordedDates(
                Set(summaries.map { CalendarDate($0.date) }),
                for: year
            )
        }
    }

    private func cancelTasks() {
        // 저장 태스크를 취소하면 완료 클로저가 상태를 되돌리지 못한다 — 여기서 직접 풀어 준다.
        state.gallerySave = .idle
        canvasLoadTask?.cancel()
        recordedDatesLoadTask?.cancel()
        recordedYearsLoadTask?.cancel()
        gallerySaveTask?.cancel()
        gallerySaveTask = nil
        canvasLoadTask = nil
        recordedDatesLoadTask = nil
        recordedYearsLoadTask = nil
        didLoadInitialData = false
    }
}
