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
    @ObservationIgnored private let canvasRefreshTicker = CanvasRefreshTicker()
    private var canvasLoadTask: Task<Void, Never>?
    /// 5초 주기 갱신 전용 핸들. 명시적 조회(`canvasLoadTask`)와 섞으면 서로를 취소한다.
    private var silentRefreshTask: Task<Void, Never>?
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
    /// 저장 미리보기 Store 가 같은 토핑 캐시를 쓰도록 합성기를 그대로 넘긴다.
    var canvasImageExporter: CanvasImageExporter { dependencies.canvasImageExporter }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared,
             .sceneBecameActive,
             .sceneEnteredBackground,
             .screenDisappeared,
             .refreshRequested,
             .canvasRefreshTicked:
            handleLifecycleIntent(intent)

        case .toppingTapped,
             .toppingImageLoaded,
             .toppingImageLoadFailed:
            handleToppingIntent(intent)

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

        case .savePreviewRequested,
             .savePreviewClosed:
            handleGallerySaveIntent(intent)

        case .todayParfaitTapped:
            openTodayCanvas()

        case .pastParfaitNudgeTapped:
            openPastParfaitNudgeTarget()

        case .moreMenuTapped: // 사이드메뉴(S-101) 이동은 View 가 라우터로 — 여긴 오버레이만 걷는다.
            state.calendar.close()
            state.menuState = .collapsed
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
            refreshCanvasSilently()
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
            refreshCanvasSilently()
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

    /// 날짜 바 `Ic_Save` — 마감 전후와 무관하게 C-001-Save-Preview 를 연다. 합성·저장은 미리보기 Store 몫이다.
    private func handleGallerySaveIntent(_ intent: Intent) {
        switch intent {
        case .savePreviewRequested:
            state.calendar.close()
            state.menuState = .collapsed
            guard let canvasContent = state.canvasContent else {
                eventChannel.send(state.contentState == .empty ? .canvasEmpty : .canvasNotReady)
                return
            }
            state.savePreview = SavePreview(date: state.calendar.selectedDate, canvasContent: canvasContent)
        case .savePreviewClosed(let reason):
            let savedDate = state.savePreview?.date
            state.savePreview = nil
            refreshCanvasSilently()
            guard let event = reason.event(dateText: savedDate?.koreanDateText) else { return }
            // 미리보기가 닫히는 순간에는 캔버스 화면이 아직 재구독 전일 수 있다.
            eventChannel.sendOrHold(event)
        default:
            break
        }
    }

    /// SY-001-Closed `오늘의 캔버스로 가기` — 같은 화면에서 오늘 캔버스로 되돌린다.
    private func openTodayCanvas() {
        state.menuState = .collapsed
        guard state.calendar.selectDate(state.calendar.today) else { return }
        loadCanvas(for: state.calendar.today)
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
        state.loadedToppingImageIDs = []
        state.failedToppingImageIDs = []
        state.awaitedToppingImageIDs = []
        toppingAuthorsByID = [:]
        // 조회가 끝나기 전에는 쓸 대상이 없다. 남겨 두면 캔버스를 전환하는 동안 토핑 추가·편집이
        // **이전 캔버스** 로 나간다 (과거 → 오늘 전환 직후가 특히 위험하다).
        state.parfaitID = nil

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
}

private extension CanvasStore {
    /// SY-001-New 는 마감 날짜당 한 번만 알린다 — 안내할 날짜를 기기에 남기고, 이미 남긴 날짜는 거른다.
    /// 첫 조회는 항상 오늘 캔버스라 여기서 기록해도 안내 없이 소모되는 일은 없다.
    func unseenClosedDate(_ closedDate: CalendarDate?) -> CalendarDate? {
        guard let closedDate else { return nil }
        let seenClosedDateKey = "canvas.seenClosedDate.\(dependencies.groupID)"
        let closedDateText = "\(closedDate.year)-\(closedDate.month)-\(closedDate.day)"
        guard UserDefaults.standard.string(forKey: seenClosedDateKey) != closedDateText else { return nil }
        UserDefaults.standard.set(closedDateText, forKey: seenClosedDateKey)
        return closedDate
    }

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
            startCanvasRefreshTicker()
        case .sceneBecameActive:
            state.spotlightedToppingID = nil
            reloadIfDayChanged()
            startCanvasRefreshTicker()
        case .sceneEnteredBackground:
            canvasRefreshTicker.stop()
        case .screenDisappeared:
            canvasRefreshTicker.stop()
            cancelTasks()
        case .refreshRequested:
            refreshCanvas()
        case .canvasRefreshTicked:
            refreshCanvasSilently()
        default:
            break
        }
    }

    private func startCanvasRefreshTicker() {
        canvasRefreshTicker.start { [weak self] in
            self?.send(.canvasRefreshTicked)
        }
    }

    func handleToppingIntent(_ intent: Intent) {
        switch intent {
        case .toppingTapped(let toppingID):
            handleToppingTap(toppingID)
        case .toppingImageLoaded(let toppingID):
            state.loadedToppingImageIDs.insert(toppingID)
        case .toppingImageLoadFailed(let toppingID):
            state.failedToppingImageIDs.insert(toppingID)
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

    /// 5초 주기 자동 최신화 — 로딩 딤도 토스트도 없이 조용히 반영한다. 실패한 틱은 그냥 건너뛴다.
    /// 덮개(토핑 추가·편집·저장 미리보기)가 올라와 있으면 그 화면이 각자 갱신한다.
    func refreshCanvasSilently() {
        guard !state.isClosedCanvas,
              silentRefreshTask == nil,
              state.loadingOverlay == .hidden,
              state.spotlightedToppingID == nil,
              state.toppingAddSource == nil,
              state.canvasEditDestination == nil,
              state.savePreview == nil
        else { return }

        let requestedDate = state.calendar.today
        silentRefreshTask = Task { [weak self, dependencies] in
            let parfait = try? await dependencies.canvasUseCase.fetchToday(groupID: dependencies.groupID)
            guard !Task.isCancelled, let self else { return }
            silentRefreshTask = nil
            guard let parfait, !state.isClosedCanvas, state.calendar.selectedDate == requestedDate else { return }
            applySilently(parfait)
        }
    }

    func apply(_ parfait: Parfait) {
        state.lastClosedDate = unseenClosedDate(parfait.lastClosedDate.map(CalendarDate.init))
        applyContent(parfait)
        state.awaitedToppingImageIDs = Set(state.canvasContent?.images.map(\.id) ?? [])
    }

    /// 주기 갱신 전용 반영. `lastClosedDate` 는 건드리지 않는다 — `unseenClosedDate` 가
    /// UserDefaults 를 소비해, 틱마다 부르면 SY-001-New 안내가 뜨자마자 사라진다.
    func applySilently(_ parfait: Parfait) {
        applyContent(parfait)
        // 새로 들어온 토핑까지 로딩 딤이 기다리지 않게 집합은 넓히지 않고, 사라진 토핑만 걷어낸다.
        state.awaitedToppingImageIDs.formIntersection(Set(state.canvasContent?.images.map(\.id) ?? []))
    }

    func applyContent(_ parfait: Parfait) {
        state.parfaitID = parfait.id
        // 그룹명은 응답 값을 우선 사용한다. 없으면(과거 스키마) 진입점이 들고 온 값을 유지한다.
        if let groupName = parfait.groupName {
            state.groupName = groupName
        }
        state.members = parfait.members.map(Member.init)
        parfaitIDsByDate[CalendarDate(parfait.date)] = parfait.id

        guard !parfait.isEmpty else {
            state.contentState = .empty
            state.canvasContent = nil
            toppingAuthorsByID = [:]
            return
        }
        state.contentState = .filled
        state.canvasContent = CanvasContent(parfait)
        toppingAuthorsByID = Dictionary(uniqueKeysWithValues: parfait.toppings.map { ($0.id, ToppingAuthor($0)) })
    }

    func cancelTasks() {
        // 미리보기(`savePreview`)는 건드리지 않는다. 덮인 화면이 `onDisappear` 를 받는지는
        // SwiftUI 버전을 타는데, 여기서 지우면 미리보기가 뜨자마자 닫혀 버린다.
        if state.contentState == .loading { didLoadInitialData = false }
        canvasLoadTask?.cancel()
        silentRefreshTask?.cancel()
        recordedDatesLoadTask?.cancel()
        recordedYearsLoadTask?.cancel()
        canvasLoadTask = nil
        silentRefreshTask = nil
        recordedDatesLoadTask = nil
        recordedYearsLoadTask = nil
    }
}
