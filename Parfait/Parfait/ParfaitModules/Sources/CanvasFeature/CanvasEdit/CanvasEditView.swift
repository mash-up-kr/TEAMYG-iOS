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
    @State private var borderTopping: CGImage?
    @State private var borderSilhouette: CGImage?
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
        // 토핑 이미지와 테두리 실루엣을 **따로** 받는다. 한 task 로 묶으면 굵기 슬라이더를
        // 움직일 때마다 토핑까지 다시 로드하며 미리보기가 스피너로 깜빡인다.
        .task(id: store.state.borderEditingTopping?.imageURL) {
            await loadBorderTopping()
        }
        .task(id: borderSilhouetteKey) {
            await loadBorderSilhouette()
        }
    }

    private var backgroundEditor: some View {
        editorSurface {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    backgroundCanvasBoard
                        .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)
                        .frame(width: backgroundContentWidth(fitting: proxy.size))

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
                .frame(width: toppingContentWidth(fitting: proxy.size))
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
                topping: borderTopping,
                silhouette: borderSilhouette,
                border: store.state.borderEditor.border,
                canUndo: store.state.borderEditor.canUndo,
                canRedo: store.state.borderEditor.canRedo,
                onUndoTap: { store.send(.borderUndoTapped) },
                onRedoTap: { store.send(.borderRedoTapped) },
                onWidthChange: { store.send(.borderWidthChanged($0)) },
                onWidthEditingChange: { store.send(.borderWidthEditingChanged($0)) },
                onColorSelect: { store.send(.borderColorSelected($0)) },
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

            if store.state.saveState == .saving {
                Color.black25
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.whiteFixed)
            }
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
        .clipped()
        .overlay {
            Rectangle()
                .strokeBorder(.gray500, lineWidth: 1)
        }
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

    func backgroundContentWidth(fitting availableSize: CGSize) -> CGFloat {
        let availableBoardHeight = max(availableSize.height - CanvasBackgroundPalette.height, 0)
        return min(availableSize.width - (.padding7 * 2), availableBoardHeight * CanvasArea.aspectRatio)
    }

    func toppingContentWidth(fitting availableSize: CGSize) -> CGFloat {
        let availableBoardHeight = max(availableSize.height - Self.toppingCanvasTopSpacing, 0)
        return min(availableSize.width - (.padding7 * 2), availableBoardHeight * CanvasArea.aspectRatio)
    }

    var borderSilhouetteKey: BorderSilhouetteKey? {
        guard let topping = store.state.borderEditingTopping,
              store.state.borderEditor.border.isVisible
        else { return nil }
        return BorderSilhouetteKey(
            imageURL: topping.imageURL,
            borderWidth: store.state.borderEditor.border.width
        )
    }

    /// 테두리 편집(C-306)은 토핑 한 장을 화면 가득 띄운다. 한 장뿐이라 원본 해상도를 그대로 쓴다.
    func loadBorderTopping() async {
        guard let imageURL = store.state.borderEditingTopping?.imageURL else {
            borderTopping = nil
            return
        }
        // 이미 그려 둔 토핑은 새 이미지가 도착할 때까지 그대로 둔다 — 화면이 비지 않게.
        let topping = await toppingRenderer.topping(
            at: imageURL,
            neededLongEdge: ToppingImageEncoder.maximumLongEdge
        )
        guard !Task.isCancelled else { return }
        borderTopping = topping
    }

    /// 굵기가 바뀔 때마다 여기만 다시 돈다. 토핑 이미지는 건드리지 않는다.
    func loadBorderSilhouette() async {
        guard let key = borderSilhouetteKey else {
            borderSilhouette = nil
            return
        }
        // 토핑 로드가 아직 안 끝났을 수 있다 — 캐시에서 다시 받아 온다(대개 즉시 반환).
        var topping = borderTopping
        if topping == nil {
            topping = await toppingRenderer.topping(
                at: key.imageURL,
                neededLongEdge: ToppingImageEncoder.maximumLongEdge
            )
        }
        guard !Task.isCancelled, let topping else { return }

        let silhouette = await toppingRenderer.silhouette(
            of: topping,
            at: key.imageURL,
            width: key.borderWidth
        )
        guard !Task.isCancelled else { return }
        borderSilhouette = silhouette
    }

    struct BorderSilhouetteKey: Equatable {
        let imageURL: URL
        let borderWidth: Double
    }
}
