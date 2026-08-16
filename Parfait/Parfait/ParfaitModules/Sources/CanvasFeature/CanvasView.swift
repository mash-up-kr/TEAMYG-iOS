//
//  CanvasView.swift
//  CanvasFeature
//
//  Created by 박서연 on 7/30/26.
//

import SwiftUI
import UIComponent

/// 토핑 추가 플로우 Store 를 만드는 팩토리. 실제 조립은 Composition Root(App) 가 소유한다.
public typealias ToppingAddStoreFactory = @MainActor (
    _ entryPoint: ToppingAddStore.PhotoSelectionEntryPoint,
    _ canvasDate: CanvasStore.CalendarDate,
    _ onFlowClosed: @escaping @MainActor @Sendable () async -> Void
) -> ToppingAddStore

public struct CanvasView: View {
    @State private var store: CanvasStore
    @Environment(\.dismiss) private var dismiss
    private let makeToppingAddStore: ToppingAddStoreFactory

    public init(
        store: CanvasStore,
        makeToppingAddStore: @escaping ToppingAddStoreFactory
    ) {
        _store = State(initialValue: store)
        self.makeToppingAddStore = makeToppingAddStore
    }

    public var body: some View {
        ZStack {
            CanvasDotGridBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                YGTopBar(
                    .canvas(title: store.state.groupName, members: topBarMembers),
                    onLeadingTap: { dismiss() },
                    onTrailingTap: { store.send(.moreMenuTapped) }
                )

                CanvasContainer(
                    state: store.state,
                    send: { store.send($0) }
                )
            }
        }
        .task {
            store.send(.screenAppeared)
        }
        .onDisappear {
            store.send(.screenDisappeared)
        }
        .navigationDestination(item: toppingAddSourceBinding) { source in
            switch source {
            case .camera(let canvasDate):
                ToppingAddFlowView(
                    store: makeToppingAddStore(.camera, canvasDate) {
                        store.send(.toppingAddFlowDismissed)
                    }
                )
            }
        }
    }

    private var toppingAddSourceBinding: Binding<CanvasStore.ToppingAddSource?> {
        Binding(
            get: { store.state.toppingAddSource },
            set: { source in
                if source == nil {
                    store.send(.toppingAddFlowDismissed)
                }
            }
        )
    }

    private var topBarMembers: [YGTopBar.Member] {
        store.state.members.map {
            YGTopBar.Member(nickname: $0.nickname, nametagType: $0.nametagType)
        }
    }
}

// 아래 프리뷰들은 `ToppingAddStore+Preview.swift` 의 가짜 팩토리에 의존한다.
// 프리뷰를 걷어낼 땐 그 파일과 함께 지운다 (제품 코드 영향 없음).
#Preview("Empty") {
    NavigationStack {
        CanvasView(
            store: CanvasStore(
                state: .init(members: CanvasStore.Member.defaultMembers),
                dependencies: .init(
                    loadCanvas: { _ in .empty },
                    loadRecordedDates: { _ in [] },
                    loadRecordedYears: { [] }
                )
            ),
            makeToppingAddStore: ToppingAddStore.previewFactory
        )
    }
}

#Preview("Calendar") {
    let today = CanvasStore.CalendarDate(year: 2026, month: 8, day: 4)
    let selectedDate = CanvasStore.CalendarDate(year: 2026, month: 8, day: 1)

    NavigationStack {
        CanvasView(
            store: CanvasStore(
                state: .init(
                    members: CanvasStore.Member.defaultMembers,
                    contentState: .filled,
                    calendar: .init(
                        selectedDate: selectedDate,
                        recordedDates: [
                            .init(year: 2026, month: 4, day: 28),
                            .init(year: 2026, month: 4, day: 29),
                            .init(year: 2026, month: 5, day: 1),
                            .init(year: 2026, month: 5, day: 2),
                            selectedDate
                        ],
                        today: today,
                        presentation: .grid
                    )
                ),
                dependencies: .init(
                    loadCanvas: { _ in .empty },
                    loadRecordedDates: { _ in [] },
                    loadRecordedYears: { [] }
                )
            ),
            makeToppingAddStore: ToppingAddStore.previewFactory
        )
    }
}
