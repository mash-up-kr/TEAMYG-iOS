//
//  CanvasStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 7/30/26.
//

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

    public init(
        state: State = State(),
        dependencies: Dependencies
    ) {
        self.state = state
        self.dependencies = dependencies
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            loadInitialDataIfNeeded()

        case .screenDisappeared:
            cancelTasks()

        case .canvasEditTapped:
            state.calendar.close()
            state.menuState = .collapsed
            // 캔버스 편집 화면이 확정되면 일회성 라우팅 이벤트를 연결한다.

        case .toppingAddTapped:
            state.calendar.close()
            state.menuState = state.menuState == .collapsed ? .sourceOptions : .collapsed

        case .cameraOptionTapped, .galleryOptionTapped:
            // 이미지 획득·편집 정책 확정 후 각 시스템 피커를 연결한다.
            break

        case .calendarTapped,
             .calendarDimTapped,
             .calendarMonthTapped,
             .calendarYearTapped,
             .calendarMonthSelected,
             .calendarYearSelected,
             .calendarDateSelected:
            handleCalendarIntent(intent)

        case .memberListTapped, .moreMenuTapped:
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

    private func loadCanvas(for date: CalendarDate) {
        canvasLoadTask?.cancel()

        state.contentState = .loading
        state.canvasContent = nil

        canvasLoadTask = Task { [weak self, dependencies] in
            let loadResult = await dependencies.loadCanvas(date)
            guard !Task.isCancelled, let self else { return }

            switch loadResult {
            case .empty:
                state.contentState = .empty
            case .filled(let content):
                state.contentState = .filled
                state.canvasContent = content
            }
        }
    }

    private func loadInitialDataIfNeeded() {
        guard !didLoadInitialData else { return }
        didLoadInitialData = true

        let selectedDate = state.calendar.selectedDate
        loadCanvas(for: selectedDate)
        loadRecordedDates(for: selectedDate.year)

        recordedYearsLoadTask = Task { [weak self, dependencies] in
            let recordedYears = await dependencies.loadRecordedYears()
            guard !Task.isCancelled, let self else { return }
            state.calendar.recordedYears = recordedYears
        }
    }

    private func loadRecordedDates(for year: Int) {
        recordedDatesLoadTask?.cancel()
        recordedDatesLoadTask = Task { [weak self, dependencies] in
            let recordedDates = await dependencies.loadRecordedDates(year)
            guard !Task.isCancelled, let self else { return }
            state.calendar.replaceRecordedDates(recordedDates, for: year)
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
        public let loadCanvas: @Sendable (CalendarDate) async -> CanvasLoadResult
        public let loadRecordedDates: @Sendable (Int) async -> Set<CalendarDate>
        public let loadRecordedYears: @Sendable () async -> Set<Int>

        public init(
            loadCanvas: @escaping @Sendable (CalendarDate) async -> CanvasLoadResult,
            loadRecordedDates: @escaping @Sendable (Int) async -> Set<CalendarDate>,
            loadRecordedYears: @escaping @Sendable () async -> Set<Int>
        ) {
            self.loadCanvas = loadCanvas
            self.loadRecordedDates = loadRecordedDates
            self.loadRecordedYears = loadRecordedYears
        }
    }

    struct State: Equatable, Sendable {
        public var groupName: String
        public var members: [Member]
        public var contentState: ContentState
        public var canvasContent: CanvasContent?
        public var menuState: MenuState
        public var calendar: CalendarState

        public init(
            groupName: String = "그룹이름",
            members: [Member] = [],
            contentState: ContentState? = nil,
            canvasContent: CanvasContent? = nil,
            menuState: MenuState = .collapsed,
            calendar: CalendarState = CalendarState()
        ) {
            self.groupName = groupName
            self.members = members
            self.contentState = contentState ?? calendar.contentState(for: calendar.selectedDate)
            self.canvasContent = canvasContent
            self.menuState = menuState
            self.calendar = calendar
        }

        public var dateText: String {
            calendar.dateText
        }

        public var weekdayText: String {
            calendar.weekdayText
        }

        public var overflowMemberCount: Int {
            max(0, members.count - 5)
        }
    }

    struct Member: Equatable, Identifiable, Sendable {
        public let id: Int
        public let nickname: String

        public init(id: Int, nickname: String) {
            self.id = id
            self.nickname = nickname
        }

        public static let defaultMembers = [
            Member(id: 1, nickname: "김"),
            Member(id: 2, nickname: "박"),
            Member(id: 3, nickname: "신"),
            Member(id: 4, nickname: "전"),
            Member(id: 5, nickname: "전"),
            Member(id: 6, nickname: "이")
        ]
    }

    enum ContentState: Equatable, Sendable {
        case empty
        case loading
        case filled
    }

    enum CanvasLoadResult: Equatable, Sendable {
        case empty
        case filled(CanvasContent)
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

        public init(
            id: Int,
            imageURL: URL,
            positionX: Double,
            positionY: Double,
            positionZ: Double,
            scale: Double = 1,
            rotation: Double = 0,
            border: CanvasImageBorder? = nil
        ) {
            self.id = id
            self.imageURL = imageURL
            self.positionX = positionX
            self.positionY = positionY
            self.positionZ = positionZ
            self.scale = scale
            self.rotation = rotation
            self.border = border
        }
    }

    struct CanvasImageBorder: Equatable, Sendable {
        public let colorHex: String
        public let width: Double

        public init(colorHex: String, width: Double) {
            self.colorHex = colorHex
            self.width = width
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
        case toppingAddTapped
        case cameraOptionTapped
        case galleryOptionTapped
        case calendarTapped
        case calendarDimTapped
        case calendarMonthTapped
        case calendarYearTapped
        case calendarMonthSelected(Int)
        case calendarYearSelected(Int)
        case calendarDateSelected(CalendarDate)
        case memberListTapped
        case moreMenuTapped
    }
}
