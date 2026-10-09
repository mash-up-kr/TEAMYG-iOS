//
//  GroupStore.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import GroupDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class GroupStore: MVIStore {
    public private(set) var state = State()

    private let groupUseCase: any GroupUseCase
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// 로드 세대 번호. 새 로드가 시작되면 올라가고, 이전 로드는 자기 세대가 아니면 아무것도 하지 않는다.
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var emptyGuideTask: Task<Void, Never>?

    private static let emptyGuideStepOffsets: [Duration] = [
        .milliseconds(500), .milliseconds(1000), .milliseconds(1500), .milliseconds(2500)
    ]
    private static let emptyGuideDuration = Duration.milliseconds(3000)

    public init(groupUseCase: any GroupUseCase) {
        self.groupUseCase = groupUseCase
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            // 드롭다운 항목으로 들어갔던 화면에서 돌아오면 열린 채로 남으므로 여기서 닫는다.
            //
            // `screenDisappeared` 에서 닫으면 안 된다 — 드롭다운의 `NavigationLink` 가 조건부 뷰라,
            // push 직후 `onDisappear` 에서 플래그를 내리면 링크가 트리에서 사라지며 push 가 취소된다.
            state.isAddGroupMenuPresented = false
            // 0건 안내는 진입할 때마다 처음부터 다시 재생한다 — 이번 진입의 조회 결과가 0건으로 확정되면 시작.
            resetEmptyGuide()
            beginLoad(isRefresh: false)
        case .refreshRequested:
            beginLoad(isRefresh: true)
        case .groupsLoaded(let groups):
            state.phase = .loaded(groups)
            if !groups.isEmpty {
                resetEmptyGuide()
            } else if state.emptyGuide == .idle {
                playEmptyGuide()
            }
        case .loadFailed:
            state.phase = .failed
        case .backgroundTapped:
            // 0건 안내는 재생이 끝난 뒤의 탭에만 닫힌다 — 재생 중 탭은 무시한다.
            if state.emptyGuide == .completed {
                state.emptyGuide = .dismissed
            }
            state.isAddGroupMenuPresented = false
        case .addGroupTapped:
            // 재생 중에 누르면 안내를 완료 상태로 넘기고 드롭다운을 연다. 안내는 닫지 않는다.
            completeEmptyGuideIfPlaying()
            state.isAddGroupMenuPresented.toggle()
        case .addGroupMenuDismissed:
            state.isAddGroupMenuPresented = false
        case .emptyGuideStepReached(let revealedStepCount):
            guard case .playing = state.emptyGuide else { return }
            state.emptyGuide = .playing(revealedStepCount: revealedStepCount)
        case .emptyGuidePlaybackFinished:
            guard case .playing = state.emptyGuide else { return }
            state.emptyGuide = .completed
        case .enteredBackground:
            completeEmptyGuideIfPlaying()
        case .screenDisappeared:
            loadTask?.cancel()
            loadTask = nil
            emptyGuideTask?.cancel()
            emptyGuideTask = nil
        }
    }

    private func playEmptyGuide() {
        emptyGuideTask?.cancel()
        state.emptyGuide = .playing(revealedStepCount: 0)
        emptyGuideTask = Task {
            let clock = ContinuousClock()
            let startInstant = clock.now
            do {
                for (index, offset) in Self.emptyGuideStepOffsets.enumerated() {
                    try await clock.sleep(until: startInstant + offset)
                    try Task.checkCancellation()
                    send(.emptyGuideStepReached(index + 1))
                }
                try await clock.sleep(until: startInstant + Self.emptyGuideDuration)
                try Task.checkCancellation()
                send(.emptyGuidePlaybackFinished)
            } catch {
                return
            }
        }
    }

    private func completeEmptyGuideIfPlaying() {
        guard case .playing = state.emptyGuide else { return }
        emptyGuideTask?.cancel()
        emptyGuideTask = nil
        state.emptyGuide = .completed
    }

    private func resetEmptyGuide() {
        emptyGuideTask?.cancel()
        emptyGuideTask = nil
        state.emptyGuide = .idle
    }

    /// `.refreshable` 이 완료를 기다릴 수 있게 열어둔 async 진입점.
    /// 상태 변이는 그대로 `send` 를 거친다 — 여기서 state 를 직접 건드리지 않는다.
    public func refresh() async {
        send(.refreshRequested)
        await loadTask?.value
    }

    /// 최초 로딩만 로딩 화면을 띄운다. 당겨서 새로고침은 시스템 인디케이터가 이미 보이므로
    /// 기존 목록을 그대로 두고 결과가 오면 갈아끼운다.
    ///
    /// 새로고침은 진행 중인 로드를 취소하고 다시 시작한다 — 그냥 무시하면 마지막 요청 결과가
    /// 반영되지 않고 이전 응답이 화면에 남는다. 최초 로딩은 반대로 중복 실행을 막는다.
    private func beginLoad(isRefresh: Bool) {
        if isRefresh {
            loadTask?.cancel()
        } else {
            guard loadTask == nil else { return }
            if case .idle = state.phase {
                state.phase = .loading
            }
        }
        loadGeneration += 1
        let generation = loadGeneration
        loadTask = Task {
            await loadGroups(generation: generation)
            // 그 사이 새 로드가 시작됐다면 그건 남의 핸들이다 — 지우면 취소도 대기도 못 한다.
            if generation == loadGeneration {
                loadTask = nil
            }
        }
    }

    /// 취소가 통하지 않는 구현(취소 지점이 없는 저장소)도 있어, 결과를 반영하기 전에
    /// 자기 세대인지 한 번 더 본다 — 늦게 도착한 옛 응답이 새 응답을 덮지 않도록.
    private func loadGroups(generation: Int) async {
        do {
            let groups = try await groupUseCase.fetchGroups()
            guard generation == loadGeneration else { return }
            send(.groupsLoaded(groups))
        } catch is CancellationError {
            // 화면 이탈로 취소됨 — 실패로 오인하지 않는다.
        } catch {
            guard generation == loadGeneration else { return }
            send(.loadFailed)
        }
    }

    public struct State: Equatable {
        public var phase = Phase.idle
        public var emptyGuide = EmptyGuide.idle
        public var isAddGroupMenuPresented = false

        public var groups: [ParfaitGroup] {
            if case .loaded(let groups) = phase { return groups }
            return []
        }

        public var groupCount: Int? {
            guard case .loaded(let groups) = phase else { return nil }
            return groups.count
        }

        /// 그룹 0건이면 진입할 때마다 노출 — 최초 1회 플래그는 두지 않는다.
        public var isEmptyGuidePresented: Bool {
            guard case .loaded(let groups) = phase, groups.isEmpty else { return false }
            switch emptyGuide {
            case .playing, .completed: return true
            case .idle, .dismissed: return false
            }
        }

        public var revealedDummyGroupCount: Int {
            min(revealedEmptyGuideStepCount, EmptyGuide.dummyGroupCount)
        }

        public var isEmptyGuideTooltipRevealed: Bool {
            revealedEmptyGuideStepCount > EmptyGuide.dummyGroupCount
        }

        private var revealedEmptyGuideStepCount: Int {
            switch emptyGuide {
            case .playing(let revealedStepCount): revealedStepCount
            case .completed: EmptyGuide.stepCount
            case .idle, .dismissed: 0
            }
        }

        public var isFailed: Bool { phase == .failed }
    }

    public enum Phase: Equatable {
        case idle
        case loading
        case loaded([ParfaitGroup])
        case failed
    }

    public enum EmptyGuide: Equatable {
        case idle
        case playing(revealedStepCount: Int)
        case completed
        case dismissed

        public static let dummyGroupCount = 3
        public static let stepCount = dummyGroupCount + 1
    }

    public enum Intent {
        case screenAppeared
        case refreshRequested
        /// `loadGroups()` 결과 — View 가 아니라 Store 내부에서만 보낸다.
        case groupsLoaded([ParfaitGroup])
        case loadFailed
        /// 화면(드롭다운 바깥) 탭.
        case backgroundTapped
        case addGroupTapped
        case addGroupMenuDismissed
        case emptyGuideStepReached(Int)
        case emptyGuidePlaybackFinished
        case enteredBackground
        case screenDisappeared
    }
}
