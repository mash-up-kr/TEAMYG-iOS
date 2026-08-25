//
//  CanvasView.swift
//  CanvasFeature
//
//  Created by 박서연 on 7/30/26.
//

import SwiftUI
import UIComponent

public struct CanvasView: View {
    @State private var store: CanvasStore
    @Environment(\.dismiss) private var dismiss

    public init(store: CanvasStore) {
        _store = State(initialValue: store)
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
                ToppingAddFlowView(store: ToppingAddStore(canvasDate: canvasDate))
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
            )
        )
    }
}

#Preview("Calendar") {
    let today = CalendarDate(year: 2026, month: 8, day: 4)
    let selectedDate = CalendarDate(year: 2026, month: 8, day: 1)

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
            )
        )
    }
}
