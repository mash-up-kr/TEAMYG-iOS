//
//  CanvasStore+State.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CanvasDomain
import Foundation
import UIComponent

/// 캔버스 조회가 시작조차 못 하는 경우.
enum CanvasLoadError: Error {
    /// 과거 날짜인데 목록에서 받아 둔 `parfaitID` 매핑이 없다.
    case unknownParfait
}

extension CanvasStore.Dependencies {
    /// 오늘은 전용 조회를, 과거는 목록에서 받아 둔 `parfaitID` 를 쓴다.
    /// 과거 날짜인데 매핑이 없으면 오늘로 흘리지 않고 실패로 돌린다 — 헤더는 과거 날짜인데
    /// 내용은 오늘인 화면을 정상처럼 보여주면 안 된다.
    func fetchParfait(isToday: Bool, parfaitID: Int?) async throws -> Parfait {
        guard !isToday else { return try await canvasUseCase.fetchToday(groupID: groupID) }
        guard let parfaitID else { throw CanvasLoadError.unknownParfait }
        return try await canvasUseCase.fetchParfait(groupID: groupID, parfaitID: parfaitID)
    }

    /// 캔버스를 한 장으로 합성해 기기 사진 앨범에 저장한다. 합성·저장 중 하나라도 실패하면 `false`.
    func saveToGallery(_ content: CanvasStore.CanvasContent) async -> Bool {
        guard let canvasImage = await canvasImageExporter.image(of: content) else { return false }
        return await CanvasGallerySaver.save(canvasImage)
    }
}

public extension CanvasStore {
    struct Dependencies: Sendable {
        public let groupID: Int
        public let canvasUseCase: any CanvasUseCase
        /// 과거 캔버스를 사진 앨범에 저장할 때 쓰는 합성기. 토핑 캐시를 화면과 공유한다.
        public let canvasImageExporter: CanvasImageExporter
        public let now: @Sendable () -> Date

        public init(
            groupID: Int,
            canvasUseCase: any CanvasUseCase,
            canvasImageExporter: CanvasImageExporter,
            now: @escaping @Sendable () -> Date = { .now }
        ) {
            self.groupID = groupID
            self.canvasUseCase = canvasUseCase
            self.canvasImageExporter = canvasImageExporter
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
        /// 갤러리 저장 진행 상태 — 저장 중 재탭을 막는다.
        var gallerySave: GallerySavePhase = .idle
        /// 가장 최근 마감된 캔버스 날짜 — SY-001-New 안내 판단용.
        public var lastClosedDate: CalendarDate?
        /// C-202 Spotlight 로 강조된 타인의 토핑 (`canvas-policy.md` §4.2).
        var spotlightedToppingID: Int?

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

        /// 과거 캔버스(SY-001-Closed)는 열람 전용이다 (`canvas-policy.md` §7.2).
        var isClosedCanvas: Bool {
            calendar.selectedDate != calendar.today
        }

        /// SY-001-New 안내 — 오늘 캔버스가 아직 발급만 되고 비어 있을 때만 최근 완성 캔버스를 알린다.
        var pastParfaitNudge: PastParfaitNudge? {
            guard !isClosedCanvas,
                  contentState != .loading,
                  status == .empty,
                  let lastClosedDate
            else { return nil }

            return PastParfaitNudge(date: lastClosedDate, friendCount: members.count)
        }
    }

    struct PastParfaitNudge: Equatable, Sendable {
        let date: CalendarDate
        let friendCount: Int

        var titleText: String {
            "\(date.koreanDateText)의 파르페 완성"
        }

        var descriptionText: String {
            "\(friendCount)명의 친구들과 함께했어요"
        }
    }

    enum GallerySavePhase: Equatable, Sendable {
        case idle
        case saving
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
        case sceneBecameActive
        case screenDisappeared
        case toppingTapped(Int)
        case spotlightDismissed
        case canvasEditTapped
        case canvasEditFlowDismissed
        case canvasEditSaved
        case toppingAddTapped
        case cameraOptionTapped
        case galleryOptionTapped
        case menuDimTapped
        case toppingAddFlowDismissed
        case toppingSaved
        case calendarTapped
        case calendarDimTapped
        case calendarMonthTapped
        case calendarYearTapped
        case calendarMonthSelected(Int)
        case calendarYearSelected(Int)
        case calendarDateSelected(CalendarDate)
        case refreshRequested
        case saveToGalleryTapped
        case todayParfaitTapped
        case pastParfaitNudgeTapped
        case moreMenuTapped
    }

    enum Event: Equatable, Sendable {
        case gallerySaveSucceeded(dateText: String)
        case gallerySaveFailed
        case canvasNotReady
        /// 조회 실패. 전용 화면 시안이 없어(`canvas-policy.md` §8) 토스트로 알린다 —
        /// 빈 캔버스와 구분되지 않으면 사용자가 "우리 캔버스가 비었다" 고 오해한다.
        case canvasLoadFailed
        case toppingSpotlighted(SpotlightToast)
    }
}
