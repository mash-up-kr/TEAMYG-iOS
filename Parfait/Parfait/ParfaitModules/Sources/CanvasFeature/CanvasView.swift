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
                CanvasTopBar(
                    groupName: store.state.groupName,
                    members: store.state.members,
                    overflowMemberCount: store.state.overflowMemberCount,
                    onBackTap: { dismiss() },
                    onMemberListTap: { store.send(.memberListTapped) },
                    onMoreMenuTap: { store.send(.moreMenuTapped) }
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
            )
        )
    }
}
