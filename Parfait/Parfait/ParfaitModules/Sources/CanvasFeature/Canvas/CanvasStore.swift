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
    /// Spotlight Toast 문구에만 쓰는 작성자 정보 — 렌더링 모델(`CanvasImage`)과 분리해 둔다.
    private var toppingAuthorsByID: [Int: ToppingAuthor] = [:]

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
    /// 캔버스 하위 편집 Store 조립에 같은 UseCase 를 전달한다.
    var canvasUseCase: any CanvasUseCase { dependencies.canvasUseCase }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared,
             .sceneBecameActive,
             .screenDisappeared,
             .refreshRequested:
            handleLifecycleIntent(intent)

        case .toppingTapped(let toppingID):
            handleToppingTap(toppingID)

        case .spotlightDismissed:
            state.spotlightedToppingID = nil
        case .canvasEditTapped,
             .canvasEditFlowDismissed,
             .canvasEditSaved:
            handleCanvasEditIntent(intent)

        case .toppingAddTapped,
             .menuDimTapped,
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

        case .pastParfaitNudgeTapped:
            openPastParfaitNudgeTarget()

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
        case .menuDimTapped:
            // 캘린더 dim 과 같다 — 바깥을 누르면 닫힌다.
            state.menuState = .collapsed
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

    /// Pull-to-Refresh — Spotlight 를 먼저 해제하고 Default 상태에서 새로고침한다 (`canvas-policy.md` §4.2).
    private func refreshCanvas() {
        state.spotlightedToppingID = nil
        state.menuState = .collapsed
        state.calendar.close()
        reload(state.calendar.selectedDate)
    }

    /// 해당 날짜의 캔버스와 그 해 기록을 함께 다시 받는다.
    private func reload(_ date: CalendarDate) {
        loadRecordedDates(for: date.year)
        loadCanvas(for: date)
    }

    /// SY-001-New `보러가기` — 안내된 날짜의 과거 캔버스로 이동한다 (`canvas-policy.md` §7.1).
    /// 안내 날짜가 다른 해면 그 해 목록을 먼저 받아 `parfaitID` 매핑을 채운다.
    private func openPastParfaitNudgeTarget() {
        guard let date = state.pastParfaitNudge?.date else { return }
        state.menuState = .collapsed

        if parfaitIDsByDate[date] != nil {
            openPastParfait(on: date)
            return
        }

        recordedDatesLoadTask?.cancel()
        recordedDatesLoadTask = Task { [weak self] in
            await self?.refreshRecordedDates(for: date.year)
            guard !Task.isCancelled, let self else { return }
            openPastParfait(on: date)
        }
    }

    /// 서버가 완성이라고 알려준 날짜라 캘린더 선택 규칙(토핑 1장 이상)과 무관하게 연다.
    private func openPastParfait(on date: CalendarDate) {
        guard state.calendar.openKnownPastDate(date) else { return }
        loadCanvas(for: date)
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
            let isSaved = await dependencies.saveToGallery(canvasContent)
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
        guard didFollowToday else {
            loadRecordedDates(for: today.year)
            return
        }
        reload(today)
    }

    private func loadCanvas(for date: CalendarDate) {
        canvasLoadTask?.cancel()

        state.contentState = .loading
        state.canvasContent = nil
        state.spotlightedToppingID = nil
        toppingAuthorsByID = [:]
        // 조회가 끝나기 전에는 쓸 대상이 없다. 남겨 두면 캔버스를 전환하는 동안 토핑 추가·편집이
        // **이전 캔버스** 로 나간다 (과거 → 오늘 전환 직후가 특히 위험하다).
        state.parfaitID = nil
        state.status = nil

        let isToday = date == state.calendar.today
        let parfaitID = parfaitIDsByDate[date]
        canvasLoadTask = Task { [weak self, dependencies] in
            do {
                let parfait = try await dependencies.fetchParfait(isToday: isToday, parfaitID: parfaitID)
                guard !Task.isCancelled, let self else { return }
                apply(parfait)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                state.contentState = .failed
                eventChannel.send(.canvasLoadFailed)
            }
        }
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
        toppingAuthorsByID = Dictionary(uniqueKeysWithValues: parfait.toppings.map { ($0.id, ToppingAuthor($0)) })
    }
}

private extension CanvasStore {
    /// 캘린더 인디케이터와 날짜 → `parfaitID` 매핑을 한 해 단위로 갱신한다.
    func refreshRecordedDates(for year: Int) async {
        let summaries = try? await dependencies.canvasUseCase.fetchSummaries(
            groupID: dependencies.groupID,
            year: year
        )
        guard !Task.isCancelled, let summaries else { return }

        for summary in summaries {
            parfaitIDsByDate[CalendarDate(summary.date)] = summary.id
        }
        state.calendar.replaceRecordedDates(
            Set(summaries.filter { $0.toppingCount > 0 }.map { CalendarDate($0.date) }),
            for: year
        )
    }

    func handleLifecycleIntent(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            state.calendar.updateToday(CalendarDate(canvasDayContaining: dependencies.now()))
            loadInitialDataIfNeeded()
        case .sceneBecameActive:
            state.spotlightedToppingID = nil
            reloadIfDayChanged()
        case .screenDisappeared:
            cancelTasks()
        case .refreshRequested:
            refreshCanvas()
        default:
            break
        }
    }

    /// 내 토핑은 C-305 로, 타인의 토핑은 Spotlight 로 간다 (`canvas-policy.md` §4.2).
    func handleToppingTap(_ toppingID: Int) {
        guard let topping = state.tappableTopping(toppingID) else { return }
        state.calendar.close()
        state.menuState = .collapsed

        if topping.isMine {
            guard state.parfaitID != nil else {
                eventChannel.send(.canvasNotReady)
                return
            }
            state.canvasEditDestination = .toppings(selectedToppingID: toppingID)
        } else {
            state.spotlightedToppingID = toppingID
            guard let author = toppingAuthorsByID[toppingID] else { return }
            eventChannel.send(.toppingSpotlighted(SpotlightToast(author: author, now: dependencies.now())))
        }
    }

    func loadInitialDataIfNeeded() {
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

    func loadRecordedDates(for year: Int) {
        recordedDatesLoadTask?.cancel()
        recordedDatesLoadTask = Task { [weak self] in
            await self?.refreshRecordedDates(for: year)
        }
    }

    func cancelTasks() {
        // 저장 태스크를 취소하면 완료 클로저가 상태를 되돌리지 못한다 — 여기서 직접 풀어 준다.
        state.gallerySave = .idle
        if state.contentState == .loading { didLoadInitialData = false }
        canvasLoadTask?.cancel()
        recordedDatesLoadTask?.cancel()
        recordedYearsLoadTask?.cancel()
        gallerySaveTask?.cancel()
        gallerySaveTask = nil
        canvasLoadTask = nil
        recordedDatesLoadTask = nil
        recordedYearsLoadTask = nil
    }
}
