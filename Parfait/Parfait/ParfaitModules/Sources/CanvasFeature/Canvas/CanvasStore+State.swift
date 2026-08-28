//
//  CanvasStore+State.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CanvasDomain
import Foundation
import UIComponent

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
        case toppingAddFlowDismissed
        case toppingSaved
        case calendarTapped
        case calendarDimTapped
        case calendarMonthTapped
        case calendarYearTapped
        case calendarMonthSelected(Int)
        case calendarYearSelected(Int)
        case calendarDateSelected(CalendarDate)
        case saveToGalleryTapped
        case todayParfaitTapped
        case pastParfaitNudgeTapped
        case moreMenuTapped
    }

    enum Event: Equatable, Sendable {
        case gallerySaveSucceeded(dateText: String)
        case gallerySaveFailed
        case canvasNotReady
        case toppingSpotlighted(SpotlightToast)
    }
}
