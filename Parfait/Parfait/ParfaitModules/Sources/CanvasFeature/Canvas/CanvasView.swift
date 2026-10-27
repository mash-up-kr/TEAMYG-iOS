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

// swiftlint:disable:next type_body_length
public struct CanvasView: View {
    @State private var store: CanvasStore
    @State private var toasts: [YGToastItem] = []
    /// 텍스트 입력(C-106)이 캔버스를 같은 자리에 겹쳐 그리도록 넘기는 캔버스 패널 화면 좌표.
    @State private var canvasBoardFrame: CGRect = .zero
    /// 지금 덮고 있는 편집 화면. Store 값이 비어도 페이드아웃이 끝날 때까지 남겨 둔다.
    @State private var presentedEditDestination: CanvasStore.CanvasEditDestination?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

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
                    send: { store.send($0) },
                    onBoardFrameChange: { canvasBoardFrame = $0 }
                )
                .ygToastOverlay($toasts)
            }
            // 이 화면엔 입력 필드가 없다 — 텍스트 입력(C-106)이 위에 떠 키보드를 올려도 캔버스가 밀려 줄었다 늘지 않게 한다.
            .ignoresSafeArea(.keyboard)

            loadingOverlay
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
                        YGToastItem(kind: .error, message: "갤러리 저장에 실패했어요, 나중에 다시 시도해 주세요")
                    )
                case .savePreviewRenderFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "저장할 이미지를 만들지 못했어요, 잠시 후 다시 시도해 주세요")
                    )
                case .canvasNotReady:
                    toasts.append(
                        YGToastItem(kind: .warning, message: "캔버스를 아직 불러오지 못했어요, 잠시 후 다시 시도해 주세요")
                    )
                case .canvasEmpty:
                    toasts.append(
                        YGToastItem(kind: .warning, message: "아직 캔버스가 비어 있어요")
                    )
                case .canvasLoadFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "캔버스를 불러오지 못했어요, 아래로 당겨 새로고침해 주세요")
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
        .onChange(of: store.state.analyticsScreenName) {
            store.send(.screenChanged)
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
            case .text:
                textToppingFlow()
            }
        }
        // 편집 화면도 텍스트 입력 화면(C-106)처럼 밀어 올리지 않고 캔버스 위에서 페이드로 띄우고 내린다.
        .onChange(of: store.state.canvasEditDestination) { _, destination in
            guard let destination else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { presentedEditDestination = destination }
        }
        .fullScreenCover(item: canvasEditDestinationBinding) { destination in
            // 내부에서 배경 이미지 피커를 push 하므로(CanvasBackgroundEditView) 스택이 필요하다.
            NavigationStack {
                // 페이드는 스택 안에서 건다 — 밖에서 걸면 캔버스 이동 신호(환경값)가 스택을 거쳐 늦게 닿아
                // 페이드가 끝난 뒤에야 캔버스가 줄어들었다.
                CanvasFadeCover(
                    isPresented: store.state.canvasEditDestination != nil,
                    canvasFrame: canvasBoardFrame,
                    onFadedOut: {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { presentedEditDestination = nil }
                    },
                    content: { canvasEditFlow(destination) }
                )
                .containerBackground(.clear, for: .navigation)
            }
            .presentationBackground(.clear)
        }
        // 푸시가 아니라 덮어 씌운다 — 캔버스 화면을 밀어내면 저장 결과 Toast 를 받을 이벤트 구독이
        // 끊겨 돌아왔을 때 알림이 사라진다.
        .fullScreenCover(item: savePreviewBinding) { savePreview in
            savePreviewFlow(savePreview)
        }
        // C-001 과 C-105 미리보기가 토핑 디코딩·실루엣 캐시를 공유한다.
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
                    onClose: { store.send(.savePreviewClosed($0)) },
                    logAnalyticsEvent: store.logAnalyticsEvent
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

    /// C-001 캔버스 자리만 뚫린 채 위에 겹쳐 뜬다 — 화면 전환 없이 그 자리에서 딤과 키보드만 올라오는 것처럼 보인다.
    private func textToppingFlow() -> some View {
        TextToppingView(
            store: TextToppingStore(
                dependencies: .init(
                    groupID: store.groupID,
                    parfaitID: store.state.parfaitID,
                    nextZOrder: store.state.canvasContent?.nextZOrder ?? 1,
                    toppingUseCase: toppingUseCase,
                    onSaved: { [store] in store.send(.textToppingSaved($0)) },
                    logAnalyticsEvent: store.logAnalyticsEvent
                )
            ),
            canvasFrame: canvasBoardFrame
        )
        .presentationBackground(.clear)
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
                    onSaved: { store.send(.toppingSaved) },
                    logAnalyticsEvent: store.logAnalyticsEvent
                ),
                makeAlbumPickerStore: makeAlbumPickerStore
            ),
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
            let editStore = CanvasEditStore(
                state: .init(
                    dateText: store.state.dateText,
                    weekdayText: store.state.weekdayText,
                    canvasContent: store.state.canvasContent ?? .empty,
                    selectedToppingID: destination.selectedToppingID,
                    selectedTextID: destination.selectedTextID
                ),
                dependencies: .init(
                    groupID: store.groupID,
                    parfaitID: parfaitID,
                    canvasUseCase: store.canvasUseCase,
                    toppingUseCase: toppingUseCase,
                    imageUploadRepository: imageUploadRepository,
                    onDismiss: { store.send(.canvasEditFlowDismissed) },
                    onSaved: { store.send(.canvasEditSaved) },
                    isToppingEdit: destination != .background,
                    logAnalyticsEvent: store.logAnalyticsEvent
                )
            )

            switch destination {
            case .background:
                CanvasBackgroundEditView(
                    store: editStore,
                    makeAlbumPickerStore: makeAlbumPickerStore,
                    toppingRenderer: toppingRenderer
                )
            case .toppings:
                CanvasToppingEditView(store: editStore, toppingRenderer: toppingRenderer)
            }
        }
    }

    private var canvasEditDestinationBinding: Binding<CanvasStore.CanvasEditDestination?> {
        Binding(
            get: { presentedEditDestination },
            set: { destination in
                presentedEditDestination = destination
                if destination == nil, store.state.canvasEditDestination != nil {
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
