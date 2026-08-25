//
//  CanvasView.swift
//  CanvasFeature
//
//  Created by 박서연 on 7/30/26.
//

import CanvasDomain
import SwiftUI
import UIComponent

public struct CanvasView: View {
    @State private var store: CanvasStore
    @Environment(\.dismiss) private var dismiss

    private let makeAlbumPickerStore: AlbumPickerStoreFactory
    private let toppingUseCase: any ToppingUseCase
    private let recentUploadsRepository: any RecentUploadsRepository
    private let toppingRenderer: CanvasToppingRenderer

    public init(
        store: CanvasStore,
        makeAlbumPickerStore: @escaping AlbumPickerStoreFactory,
        toppingUseCase: any ToppingUseCase,
        recentUploadsRepository: any RecentUploadsRepository,
        toppingRenderer: CanvasToppingRenderer
    ) {
        _store = State(initialValue: store)
        self.makeAlbumPickerStore = makeAlbumPickerStore
        self.toppingUseCase = toppingUseCase
        self.recentUploadsRepository = recentUploadsRepository
        self.toppingRenderer = toppingRenderer
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
                toppingAddFlow(canvasDate: canvasDate, photoSource: .camera)
            case .gallery(let canvasDate):
                toppingAddFlow(canvasDate: canvasDate, photoSource: .gallery)
            }
        }
        // C-001 과 C-106 미리보기가 토핑 디코딩·실루엣 캐시를 공유한다.
        .environment(\.canvasToppingRenderer, toppingRenderer)
    }

    private func toppingAddFlow(
        canvasDate: CalendarDate,
        photoSource: ToppingAddStore.PhotoSource
    ) -> some View {
        ToppingAddFlowView(
            store: ToppingAddStore(
                canvasDate: canvasDate,
                photoSource: photoSource,
                canvasContent: store.state.canvasContent,
                dependencies: .init(
                    groupID: store.groupID,
                    parfaitID: store.state.parfaitID,
                    toppingUseCase: toppingUseCase,
                    recentUploadsRepository: recentUploadsRepository,
                    onSaved: { store.send(.toppingSaved) }
                )
            ),
            makeAlbumPickerStore: makeAlbumPickerStore
        )
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
