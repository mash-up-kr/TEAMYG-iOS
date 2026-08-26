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
    private let dependencies: Dependencies
    private var canvasLoadTask: Task<Void, Never>?
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

    /// 토핑 추가 흐름이 저장 대상 캔버스를 지정할 때 쓴다.
    public var groupID: Int { dependencies.groupID }
    /// 캔버스 하위 편집 Store 조립에 같은 UseCase 인스턴스를 전달한다.
    var canvasUseCase: any CanvasUseCase { dependencies.canvasUseCase }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            loadInitialDataIfNeeded()

        case .screenDisappeared:
            cancelTasks()

        case .canvasEditTapped,
             .canvasEditFlowDismissed,
             .canvasEditSaved:
            handleCanvasEditIntent(intent)

        case .toppingAddTapped:
            state.calendar.close()
            state.menuState = state.menuState == .collapsed ? .sourceOptions : .collapsed

        case .cameraOptionTapped:
            state.calendar.close()
            state.menuState = .collapsed
            state.toppingAddSource = .camera(
                canvasDate: CalendarDate(canvasDayContaining: dependencies.now())
            )

        case .galleryOptionTapped:
            state.calendar.close()
            state.menuState = .collapsed
            state.toppingAddSource = .gallery(
                canvasDate: CalendarDate(canvasDayContaining: dependencies.now())
            )

        case .toppingAddFlowDismissed:
            state.toppingAddSource = nil

        case .toppingSaved:
            state.toppingAddSource = nil
            loadCanvas(for: state.calendar.selectedDate)

        case .calendarTapped,
             .calendarDimTapped,
             .calendarMonthTapped,
             .calendarYearTapped,
             .calendarMonthSelected,
             .calendarYearSelected,
             .calendarDateSelected:
            handleCalendarIntent(intent)

        case .moreMenuTapped:
            // 후속 화면 정책 확정 전까지 외형과 Intent 경계만 제공한다.
            break
        }
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
            state.calendar.close()
            state.menuState = .collapsed
            guard state.parfaitID != nil, state.canvasContent != nil else { return }
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
        canvasLoadTask?.cancel()
        recordedDatesLoadTask?.cancel()
        recordedYearsLoadTask?.cancel()
        canvasLoadTask = nil
        recordedDatesLoadTask = nil
        recordedYearsLoadTask = nil
        didLoadInitialData = false
    }
}

public extension CanvasStore {
    struct Dependencies: Sendable {
        public let groupID: Int
        public let canvasUseCase: any CanvasUseCase
        public let now: @Sendable () -> Date

        public init(
            groupID: Int,
            canvasUseCase: any CanvasUseCase,
            now: @escaping @Sendable () -> Date = { .now }
        ) {
            self.groupID = groupID
            self.canvasUseCase = canvasUseCase
            self.now = now
        }
    }

    struct State: Equatable, Sendable {
        public var groupName: String
        public var members: [Member]
        public var contentState: ContentState
        public var canvasContent: CanvasContent?
        public var menuState: MenuState
        public var calendar: CalendarState
        public var toppingAddSource: ToppingAddSource?
        var canvasEditDestination: CanvasEditDestination?
        /// 현재 그려진 캔버스의 서버 ID. 토핑 배치·편집이 이 값을 쓴다.
        public var parfaitID: Int?
        public var status: ParfaitStatus?
        /// 가장 최근 마감된 캔버스 날짜 — SY-001-New 안내 판단용.
        public var lastClosedDate: CalendarDate?

        public init(
            groupName: String = "그룹이름",
            members: [Member] = [],
            contentState: ContentState? = nil,
            canvasContent: CanvasContent? = nil,
            menuState: MenuState = .collapsed,
            calendar: CalendarState = CalendarState(),
            toppingAddSource: ToppingAddSource? = nil
        ) {
            self.groupName = groupName
            self.members = members
            self.contentState = contentState ?? calendar.contentState(for: calendar.selectedDate)
            self.canvasContent = canvasContent
            self.menuState = menuState
            self.calendar = calendar
            self.toppingAddSource = toppingAddSource
            canvasEditDestination = nil
        }

        public var dateText: String {
            calendar.dateText
        }

        public var weekdayText: String {
            calendar.weekdayText
        }
    }

    struct Member: Equatable, Identifiable, Sendable {
        public let id: Int
        public let nickname: String
        public let nametagChip: NametagChip

        public init(id: Int, nickname: String, nametagChip: NametagChip) {
            self.id = id
            self.nickname = nickname
            self.nametagChip = nametagChip
        }

        init(_ member: ParfaitMember) {
            id = member.id
            nickname = member.nickname
            nametagChip = member.nametagChip
        }

        var nametagType: YGNametagChip.NametagType {
            nametagChip.chipType
        }
    }

    enum ContentState: Equatable, Sendable {
        case empty
        case loading
        case filled
        /// 조회 실패. 피그마 프레임이 없어 우선 빈 캔버스와 같은 자리에 표시한다.
        case failed
    }

    struct CanvasContent: Equatable, Sendable {
        public let background: CanvasBackground
        public let images: [CanvasImage]

        public init(background: CanvasBackground, images: [CanvasImage] = []) {
            self.background = background
            self.images = images.sorted { $0.positionZ < $1.positionZ }
        }
    }

    enum CanvasBackground: Equatable, Sendable {
        case color(hex: String)
        case image(url: URL)
        /// 배경 편집에서 아직 서버에 저장하지 않은 JPEG 초안.
        case imageData(Data)
    }

    struct CanvasImage: Equatable, Identifiable, Sendable {
        public let id: Int
        public let imageURL: URL
        public let positionX: Double
        public let positionY: Double
        public let positionZ: Double
        public let scale: Double
        public let rotation: Double
        public let border: CanvasImageBorder?
        public let isMine: Bool

        public init(
            id: Int,
            imageURL: URL,
            positionX: Double,
            positionY: Double,
            positionZ: Double,
            scale: Double = 1,
            rotation: Double = 0,
            border: CanvasImageBorder? = nil,
            isMine: Bool = false
        ) {
            self.id = id
            self.imageURL = imageURL
            self.positionX = positionX
            self.positionY = positionY
            self.positionZ = positionZ
            self.scale = scale
            self.rotation = rotation
            self.border = border
            self.isMine = isMine
        }
    }

    enum MenuState: Equatable, Sendable {
        case collapsed
        case sourceOptions
    }

    enum Intent {
        case screenAppeared
        case screenDisappeared
        case canvasEditTapped
        case canvasEditFlowDismissed
        case canvasEditSaved
        case toppingAddTapped
        case cameraOptionTapped
        case galleryOptionTapped
        case toppingAddFlowDismissed
        case toppingSaved
        case calendarTapped
        case calendarDimTapped
        case calendarMonthTapped
        case calendarYearTapped
        case calendarMonthSelected(Int)
        case calendarYearSelected(Int)
        case calendarDateSelected(CalendarDate)
        case moreMenuTapped
    }
}
