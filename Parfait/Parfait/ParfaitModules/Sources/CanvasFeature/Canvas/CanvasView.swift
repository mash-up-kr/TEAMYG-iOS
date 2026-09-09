//
//  CanvasView.swift
//  CanvasFeature
//
//  Created by 박서연 on 7/30/26.
//

import CanvasDomain
import Routing
import SwiftUI
import UIComponent

public struct CanvasView: View {
    @State private var store: CanvasStore
    @State private var toasts: [YGToastItem] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// 캔버스 최초 진입 1회만 튜토리얼을 덮는다. 마지막 장 "시작하기" 를 누르면 다시 안 뜬다.
    @AppStorage(CanvasTutorialView.hasSeenDefaultsKey) private var hasSeenTutorial = false

    /// 사이드메뉴(S-101)로 나가는 통로. 피처 밖 화면이라 `AppRoute` 로 간다.
    private let router: any Router
    private let makeAlbumPickerStore: AlbumPickerStoreFactory
    private let toppingUseCase: any ToppingUseCase
    private let imageUploadRepository: any ImageUploadRepository
    private let recentUploadsRepository: any RecentUploadsRepository
    private let toppingRenderer: CanvasToppingRenderer

    public init(
        store: CanvasStore,
        router: any Router,
        makeAlbumPickerStore: @escaping AlbumPickerStoreFactory,
        toppingUseCase: any ToppingUseCase,
        imageUploadRepository: any ImageUploadRepository,
        recentUploadsRepository: any RecentUploadsRepository,
        toppingRenderer: CanvasToppingRenderer
    ) {
        _store = State(initialValue: store)
        self.router = router
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
                    onTrailingTap: {
                        store.send(.moreMenuTapped)
                        router.push(
                            .groupSideMenu(
                                groupID: String(store.groupID),
                                groupName: store.state.groupName
                            )
                        )
                    }
                )

                CanvasContainer(
                    state: store.state,
                    send: { store.send($0) }
                )
                .ygToastOverlay($toasts)
            }

            loadingOverlay

            if !hasSeenTutorial {
                CanvasTutorialView { hasSeenTutorial = true }
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
                case .savePreviewRenderFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "저장할 이미지를 만들지 못했어요. 잠시 후 다시 시도해 주세요.")
                    )
                case .canvasNotReady:
                    toasts.append(
                        YGToastItem(kind: .warning, message: "캔버스를 아직 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
                    )
                case .canvasEmpty:
                    toasts.append(
                        YGToastItem(kind: .warning, message: "아직 캔버스가 비어 있어요. 토핑을 올려 채워보세요.")
                    )
                case .canvasLoadFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "캔버스를 불러오지 못했어요. 아래로 당겨 새로고침해 주세요.")
                    )
                case .toppingSpotlighted(let spotlightToast):
                    // Spotlight 를 옮길 때마다 앞선 작성자 Toast 는 즉시 걷어낸다.
                    toasts = [spotlightToast.toastItem]
                }
            }
        }
        // `.inactive` 는 알림 배너·앱 스위처에서도 흔히 발생한다 — 주기 갱신을 껐다 켜지 않도록 `.background` 만 본다.
        .onChange(of: scenePhase) { _, newScenePhase in
            guard newScenePhase != .inactive else { return }
            store.send(newScenePhase == .active ? .sceneBecameActive : .sceneEnteredBackground)
        }
        .onDisappear {
            store.send(.screenDisappeared)
        }
        .fullScreenCover(item: toppingAddSourceBinding) { source in
            switch source {
            case .camera(let canvasDate):
                toppingAddFlow(canvasDate: canvasDate, photoSource: .camera)
            case .gallery(let canvasDate):
                toppingAddFlow(canvasDate: canvasDate, photoSource: .gallery)
            }
        }
        .fullScreenCover(item: canvasEditDestinationBinding) { destination in
            // 내부에서 배경 이미지 피커를 push 하므로(CanvasEditView) 스택이 필요하다.
            NavigationStack {
                canvasEditFlow(destination)
            }
        }
        // 푸시가 아니라 덮어 씌운다 — 캔버스 화면을 밀어내면 저장 결과 Toast 를 받을 이벤트 구독이
        // 끊겨 돌아왔을 때 알림이 사라진다.
        .fullScreenCover(item: savePreviewBinding) { savePreview in
            savePreviewFlow(savePreview)
        }
        // C-001 과 C-106 미리보기가 토핑 디코딩·실루엣 캐시를 공유한다.
        .environment(\.canvasToppingRenderer, toppingRenderer)
    }

    /// 캔버스 조회부터 토핑 이미지 다운로드까지 화면 전체를 덮는다 (C-001-Loading / C-001-Error).
    private var loadingOverlay: some View {
        ZStack {
            switch store.state.loadingOverlay {
            case .hidden:
                EmptyView()
            case .loading:
                YGLoadingView(
                    animation: .topping,
                    message: "캔버스를 불러오는 중이에요\n고화질일수록 더 오래 걸릴 수 있어요"
                )
                .transition(.opacity)
            case .imageLoadFailed:
                ZStack {
                    Color.black75.ignoresSafeArea()
                    YGErrorView(
                        tone: .onDim,
                        title: "캔버스를 불러오지 못했어요",
                        message: "아래 버튼을 눌러 다시 시도해 주세요",
                        buttonTitle: "다시 시도"
                    ) {
                        store.send(.refreshRequested)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.state.loadingOverlay)
    }

    private func savePreviewFlow(_ savePreview: CanvasStore.SavePreview) -> some View {
        CanvasSavePreviewView(
            store: CanvasSavePreviewStore(
                state: .init(
                    dateText: store.state.dateText,
                    weekdayText: store.state.weekdayText
                ),
                dependencies: .init(
                    canvasContent: savePreview.canvasContent,
                    canvasImageExporter: store.canvasImageExporter,
                    onClose: { store.send(.savePreviewClosed($0)) }
                )
            )
        )
    }

    private var savePreviewBinding: Binding<CanvasStore.SavePreview?> {
        Binding(
            get: { store.state.savePreview },
            set: { savePreview in
                if savePreview == nil {
                    store.send(.savePreviewClosed(.dismissed))
                }
            }
        )
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
                    canvasUseCase: store.canvasUseCase,
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
    private func canvasEditFlow(_ destination: CanvasStore.CanvasEditDestination) -> some View {
        if let parfaitID = store.state.parfaitID {
            CanvasEditView(
                store: CanvasEditStore(
                    state: .init(
                        dateText: store.state.dateText,
                        weekdayText: store.state.weekdayText,
                        canvasContent: store.state.canvasContent ?? .empty,
                        screen: destination.editScreen,
                        selectedToppingID: destination.selectedToppingID
                    ),
                    dependencies: .init(
                        groupID: store.groupID,
                        parfaitID: parfaitID,
                        canvasUseCase: store.canvasUseCase,
                        toppingUseCase: toppingUseCase,
                        imageUploadRepository: imageUploadRepository,
                        toppingRenderer: toppingRenderer,
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
