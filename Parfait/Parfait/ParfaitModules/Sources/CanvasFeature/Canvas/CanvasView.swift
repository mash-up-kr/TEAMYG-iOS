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
    @State private var toasts: [YGToastItem] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private let makeAlbumPickerStore: AlbumPickerStoreFactory
    private let toppingUseCase: any ToppingUseCase
    private let imageUploadRepository: any ImageUploadRepository
    private let recentUploadsRepository: any RecentUploadsRepository
    private let toppingRenderer: CanvasToppingRenderer

    public init(
        store: CanvasStore,
        makeAlbumPickerStore: @escaping AlbumPickerStoreFactory,
        toppingUseCase: any ToppingUseCase,
        imageUploadRepository: any ImageUploadRepository,
        recentUploadsRepository: any RecentUploadsRepository,
        toppingRenderer: CanvasToppingRenderer
    ) {
        _store = State(initialValue: store)
        self.makeAlbumPickerStore = makeAlbumPickerStore
        self.toppingUseCase = toppingUseCase
        self.imageUploadRepository = imageUploadRepository
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
                .ygToastOverlay($toasts)
            }
        }
        .task {
            store.send(.screenAppeared)
        }
        .task {
            for await event in store.eventStream() {
                switch event {
                case .gallerySaveSucceeded(let dateText):
                    toasts.append(
                        YGToastItem(kind: .success, message: "\(dateText)의 캔버스가 갤러리에 저장됐어요")
                    )
                case .gallerySaveFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "갤러리 저장에 실패했어요. 나중에 다시 시도해 주세요.")
                    )
                case .canvasNotReady:
                    toasts.append(
                        YGToastItem(kind: .warning, message: "캔버스를 아직 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
                    )
                }
            }
        }
        .onChange(of: scenePhase) { _, newScenePhase in
            guard newScenePhase == .active else { return }
            store.send(.sceneBecameActive)
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
        .navigationDestination(item: canvasEditDestinationBinding) { _ in
            canvasEditFlow
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
            makeAlbumPickerStore: makeAlbumPickerStore,
            toppingRenderer: toppingRenderer
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

    @ViewBuilder
    private var canvasEditFlow: some View {
        if let parfaitID = store.state.parfaitID {
            CanvasEditView(
                store: CanvasEditStore(
                    state: .init(
                        dateText: store.state.dateText,
                        weekdayText: store.state.weekdayText,
                        canvasContent: store.state.canvasContent ?? .empty
                    ),
                    dependencies: .init(
                        groupID: store.groupID,
                        parfaitID: parfaitID,
                        canvasUseCase: store.canvasUseCase,
                        toppingUseCase: toppingUseCase,
                        imageUploadRepository: imageUploadRepository,
                        onDismiss: { store.send(.canvasEditFlowDismissed) },
                        onSaved: { store.send(.canvasEditSaved) }
                    )
                ),
                makeAlbumPickerStore: makeAlbumPickerStore,
                toppingRenderer: toppingRenderer
            )
        }
    }

    private var canvasEditDestinationBinding: Binding<CanvasStore.CanvasEditDestination?> {
        Binding(
            get: { store.state.canvasEditDestination },
            set: { destination in
                if destination == nil {
                    store.send(.canvasEditFlowDismissed)
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
