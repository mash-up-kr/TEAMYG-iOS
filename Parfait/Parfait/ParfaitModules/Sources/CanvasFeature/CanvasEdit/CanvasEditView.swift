//
//  CanvasEditView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

struct CanvasEditView: View {
    private static let toppingCanvasTopSpacing: CGFloat = 53

    @State private var store: CanvasEditStore
    @State private var toasts: [YGToastItem] = []
    @Environment(\.scenePhase) private var scenePhase
    private let makeAlbumPickerStore: AlbumPickerStoreFactory
    private let toppingRenderer: CanvasToppingRenderer

    init(
        store: CanvasEditStore,
        makeAlbumPickerStore: @escaping AlbumPickerStoreFactory,
        toppingRenderer: CanvasToppingRenderer
    ) {
        _store = State(initialValue: store)
        self.makeAlbumPickerStore = makeAlbumPickerStore
        self.toppingRenderer = toppingRenderer
    }

    var body: some View {
        Group {
            switch store.state.screen {
            case .background:
                backgroundEditor
            case .toppings:
                toppingEditor
            case .border:
                borderEditor
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.canvasToppingRenderer, toppingRenderer)
        // 루트에 걸어야 딤이 하단 플로팅 바까지 덮는다.
        .ygLoading(store.state.saveState == .saving)
        .navigationDestination(item: backgroundImageSourceBinding) { source in
            BackgroundImagePickerView(
                store: BackgroundImagePickerStore(
                    state: .init(
                        dateText: store.state.dateText,
                        weekdayText: store.state.weekdayText,
                        photoSource: source
                    ),
                    dependencies: .init(
                        onImageSelected: { jpegData, selectedSource in
                            store.send(.backgroundImageSelected(jpegData, source: selectedSource))
                        }
                    )
                ),
                makeAlbumPickerStore: makeAlbumPickerStore
            )
        }
        .ygPopup(
            isPresented: exitPopupBinding,
            title: "편집을 그만둘까요?",
            description: "기존 편집 내용은 모두 사라지며\n캔버스 화면으로 돌아가요",
            secondaryTitle: "그만두기",
            primaryTitle: "계속 편집하기",
            secondaryAction: { store.send(.discardTapped) },
            primaryAction: { store.send(.continueEditingTapped) }
        )
        .ygToastOverlay($toasts)
        // 배경 이미지 피커로 push 했다 돌아와도 주기 갱신이 다시 붙도록 `onAppear` 로 짝을 맞춘다.
        .onAppear {
            store.send(.screenAppeared)
        }
        .onDisappear {
            store.send(.screenDisappeared)
        }
        .onChange(of: scenePhase) { _, newScenePhase in
            switch newScenePhase {
            case .active:
                store.send(.sceneBecameActive)
            case .background:
                store.send(.sceneEnteredBackground)
            default:
                break
            }
        }
        .task {
            for await event in store.eventStream() {
                switch event {
                case .otherToppingSelected:
                    toasts.append(YGToastItem(kind: .warning, message: "내 토핑만 편집할 수 있어요"))
                case .saveFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "편집 내용을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.")
                    )
                }
            }
        }
    }

    private var backgroundEditor: some View {
        editorSurface {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    backgroundCanvasBoard
                        .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)
                        .frame(width: contentWidth(fitting: proxy.size, reservedHeight: CanvasBackgroundPalette.height))

                    CanvasBackgroundPalette(
                        background: store.state.background,
                        selectedColorHex: store.state.selectedColorHex,
                        selectedImageSource: store.state.isImageSelected
                            ? store.state.selectedBackgroundImageSource ?? .gallery
                            : nil,
                        onColorSelect: { store.send(.colorSelected($0)) },
                        onImageSourceSelect: { store.send(.backgroundImageSourceTapped($0)) }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            editFloatingBar
        }
    }

    private var toppingEditor: some View {
        editorSurface {
            GeometryReader { proxy in
                CanvasToppingEditBoard(
                    background: store.state.background,
                    toppings: store.state.activeToppings,
                    selectedToppingID: store.state.selectedToppingID,
                    onToppingTap: { store.send(.toppingTapped($0)) },
                    onPlacementChange: {
                        store.send(.toppingPlacementChanged(toppingID: $0, placement: $1))
                    },
                    onDeleteTap: { store.send(.toppingDeleteTapped($0)) },
                    onBorderEditTap: { store.send(.toppingBorderEditTapped($0)) }
                )
                .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)
                .frame(width: contentWidth(fitting: proxy.size, reservedHeight: Self.toppingCanvasTopSpacing))
                .padding(.top, Self.toppingCanvasTopSpacing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            editFloatingBar
        }
    }

    @ViewBuilder
    private var borderEditor: some View {
        if store.state.borderEditingTopping != nil {
            ToppingBorderEditView(
                topping: store.state.borderTopping,
                silhouette: store.state.borderSilhouette?.image,
                border: store.state.borderEditor.border,
                canUndo: store.state.borderEditor.canUndo,
                canRedo: store.state.borderEditor.canRedo,
                onUndoTap: { store.send(.borderUndoTapped) },
                onRedoTap: { store.send(.borderRedoTapped) },
                onWidthChange: { store.send(.borderWidthChanged($0)) },
                onWidthEditingChange: { store.send(.borderWidthEditingChanged($0)) },
                onColorSelect: { store.send(.borderColorSelected($0)) },
                onPreviewLongEdgeChange: { store.send(.borderPreviewLongEdgeChanged($0)) },
                placementScale: store.state.borderEditingTopping?.placement.scale,
                showsAreaTab: false,
                singleTitle: "테두리 편집",
                onAreaTabTap: {},
                onCloseTap: { store.send(.borderEditClosed) },
                onConfirmTap: { store.send(.borderEditConfirmed) }
            )
        }
    }

    private func editorSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            content()
        }
        .disabled(store.state.saveState == .saving)
    }

    private var editFloatingBar: some View {
        YGFloatingBar(
            .editTab(tabs: ["배경", "토핑"], selection: editTabSelection),
            onClose: { store.send(.closeTapped) },
            onConfirm: { store.send(.confirmTapped) }
        )
        .background(.whiteFixed)
    }

    private var backgroundCanvasBoard: some View {
        ZStack {
            Color.gray100
            CanvasContentView(
                content: CanvasStore.CanvasContent(
                    background: store.state.background,
                    images: store.state.activeToppings.map(\.canvasImage)
                )
            )
        }
        .canvasBoardFrame()
    }
}

private extension CanvasEditView {
    var editTabSelection: Binding<Int> {
        store.binding(\.editTabIndex) { $0 == 0 ? .backgroundTabTapped : .toppingTabTapped }
    }

    var exitPopupBinding: Binding<Bool> {
        Binding(
            get: { store.state.showsExitPopup },
            set: { isPresented in
                if !isPresented {
                    store.send(.continueEditingTapped)
                }
            }
        )
    }

    var backgroundImageSourceBinding: Binding<BackgroundImagePickerStore.PhotoSource?> {
        Binding(
            get: { store.state.backgroundImageSource },
            set: { source in
                if source == nil {
                    store.send(.backgroundImageFlowDismissed)
                }
            }
        )
    }

    func contentWidth(fitting availableSize: CGSize, reservedHeight: CGFloat) -> CGFloat {
        let availableBoardHeight = max(availableSize.height - reservedHeight, 0)
        return min(availableSize.width - (.padding7 * 2), availableBoardHeight * CanvasArea.aspectRatio)
    }
}
