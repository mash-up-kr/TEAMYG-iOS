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
        .onChange(of: store.state.saveState) { _, saveState in
            guard saveState == .failed else { return }
            toasts.append(
                YGToastItem(kind: .error, message: "편집 내용을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.")
            )
            store.send(.saveErrorDismissed)
        }
        .task {
            for await event in store.eventStream() {
                switch event {
                case .otherToppingSelected:
                    toasts.append(YGToastItem(kind: .warning, message: "내 토핑만 편집할 수 있어요"))
                }
            }
        }
        .task(id: borderPreviewKey) {
            await loadBorderPreview()
        }
    }

    private var backgroundEditor: some View {
        editorSurface {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    backgroundCanvasBoard
                        .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)

                    CanvasBackgroundPalette(
                        selectedColorHex: store.state.selectedColorHex,
                        selectedImageSource: store.state.isImageSelected
                            ? store.state.selectedBackgroundImageSource ?? .gallery
                            : nil,
                        onColorSelect: { store.send(.colorSelected($0)) },
                        onImageSourceSelect: { store.send(.backgroundImageSourceTapped($0)) }
                    )
                }
                .frame(width: backgroundContentWidth(fitting: proxy.size))
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
        Binding(
            get: { store.state.screen == .background ? 0 : 1 },
            set: { selection in
                store.send(selection == 0 ? .backgroundTabTapped : .toppingTabTapped)
            }
        )
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
        let availableBoardHeight = max(availableSize.height - 60, 0)
        return min(availableSize.width - (.padding7 * 2), availableBoardHeight * CanvasArea.aspectRatio)
    }

    func toppingContentWidth(fitting availableSize: CGSize) -> CGFloat {
        let availableBoardHeight = max(availableSize.height - Self.toppingCanvasTopSpacing, 0)
        return min(availableSize.width - (.padding7 * 2), availableBoardHeight * CanvasArea.aspectRatio)
    }

    var borderPreviewKey: BorderPreviewKey? {
        guard let topping = store.state.borderEditingTopping else { return nil }
        return BorderPreviewKey(
            imageURL: topping.imageURL,
            borderWidth: store.state.borderEditor.border.width,
            showsBorder: store.state.borderEditor.border.isVisible
        )
    }

    func loadBorderPreview() async {
        guard let key = borderPreviewKey else {
            borderTopping = nil
            borderSilhouette = nil
            return
        }

        borderTopping = nil
        borderSilhouette = nil
        // 테두리 편집(C-306)은 토핑 한 장을 화면 가득 띄운다. 한 장뿐이라 원본 해상도를 그대로 쓴다.
        let topping = await toppingRenderer.topping(
            at: key.imageURL,
            neededLongEdge: ToppingImageEncoder.maximumLongEdge
        )
        guard !Task.isCancelled else { return }
        borderTopping = topping

        guard key.showsBorder, let topping else { return }
        let silhouette = await toppingRenderer.silhouette(
            of: topping,
            at: key.imageURL,
            width: key.borderWidth
        )
        guard !Task.isCancelled else { return }
        borderSilhouette = silhouette
    }

    struct BorderPreviewKey: Equatable {
        let imageURL: URL
        let borderWidth: Double
        let showsBorder: Bool
    }
}
