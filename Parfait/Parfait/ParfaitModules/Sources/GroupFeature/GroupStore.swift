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

    private let fetchGroupsUseCase: any FetchGroupsUseCase
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    public init(fetchGroupsUseCase: any FetchGroupsUseCase) {
        self.fetchGroupsUseCase = fetchGroupsUseCase
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            // 재진입마다 새 Store 라 툴팁도 자연히 다시 뜬다 — "0건이면 항상 노출" 정책.
            beginLoad(isRefresh: false)
        case .refreshRequested:
            beginLoad(isRefresh: true)
        case .groupsLoaded(let groups):
            state.phase = .loaded(groups)
        case .loadFailed:
            state.phase = .failed
        case .backgroundTapped:
            // 툴팁 밖 아무 데나 누르면 닫힌다. 드롭다운도 같은 제스처로 닫는다.
            state.isTooltipDismissed = true
            state.isAddGroupMenuPresented = false
        case .addGroupTapped:
            state.isAddGroupMenuPresented.toggle()
            state.isTooltipDismissed = true
        case .addGroupMenuDismissed:
            state.isAddGroupMenuPresented = false
        case .screenDisappeared:
            loadTask?.cancel()
            loadTask = nil
        }
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
        loadTask = Task {
            await loadGroups()
            loadTask = nil
        }
    }

    private func loadGroups() async {
        do {
            let groups = try await fetchGroupsUseCase.fetchGroups()
            send(.groupsLoaded(groups))
        } catch is CancellationError {
            // 화면 이탈로 취소됨 — 실패로 오인하지 않는다.
        } catch {
            send(.loadFailed)
        }
    }

    public struct State: Equatable {
        public var phase = Phase.idle
        /// 이번 진입에서 툴팁을 닫았는지. 화면을 나갔다 오면 Store 와 함께 초기화된다.
        public var isTooltipDismissed = false
        public var isAddGroupMenuPresented = false

        public var groups: [GroupDomain.Group] {
            if case .loaded(let groups) = phase { return groups }
            return []
        }

        /// 그룹 0건이면 항상 노출 — 최초 1회 플래그는 두지 않는다.
        public var isTooltipVisible: Bool {
            guard case .loaded(let groups) = phase else { return false }
            return groups.isEmpty && !isTooltipDismissed
        }

        public var isFailed: Bool { phase == .failed }
    }

    public enum Phase: Equatable {
        case idle
        case loading
        case loaded([GroupDomain.Group])
        case failed
    }

    public enum Intent {
        case screenAppeared
        case refreshRequested
        /// `loadGroups()` 결과 — View 가 아니라 Store 내부에서만 보낸다.
        case groupsLoaded([GroupDomain.Group])
        case loadFailed
        /// 툴팁·드롭다운 바깥 영역 탭.
        case backgroundTapped
        case addGroupTapped
        case addGroupMenuDismissed
        case screenDisappeared
    }
}
