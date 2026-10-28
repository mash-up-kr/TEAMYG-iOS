//
//  CanvasBackgroundEditView.swift
//  CanvasFeature
//
//  Created by 박서연 on 10/9/26.
//

import SwiftUI
import UIComponent

struct CanvasBackgroundEditView: View {
    @State private var store: CanvasEditStore
    @State private var toasts: [YGToastItem] = []
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
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()
                .canvasEditChrome()

            VStack(spacing: 0) {
                canvasBoard
                    .aspectRatio(CanvasArea.aspectRatio, contentMode: .fit)
                    .canvasBoardEntrance()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, .padding7)
                    // C-001 캔버스와 위쪽 끝을 맞춘다 — 전환 중 캔버스가 위로 올라가지 않고 아래·옆으로만 줄어든다.
                    .padding(.top, .padding6)

                CanvasBackgroundPalette(
                    background: store.state.background,
                    selectedColorHex: store.state.selectedColorHex,
                    selectedImageSource: store.state.isImageSelected
                        ? store.state.selectedBackgroundImageSource ?? .gallery
                        : nil,
                    onColorSelect: { store.send(.colorSelected($0)) },
                    onImageSourceSelect: { store.send(.backgroundImageSourceTapped($0)) }
                )
                .canvasEditChrome()
            }
        }
        .canvasEditScaffold(
            store: store,
            title: "배경 변경",
            confirmTitle: "저장하기",
            exitPopupTitle: "배경 변경을 그만둘까요?"
        )
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
                        },
                        onClose: { store.send(.backgroundImagePickerCloseTapped) }
                    )
                ),
                makeAlbumPickerStore: makeAlbumPickerStore
            )
        }
        .onAppear { store.send(.backgroundEditScreenAppeared) }
        .ygToastOverlay($toasts)
        .task {
            for await event in store.eventStream() {
                switch event {
                case .saveFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "편집 내용을 저장하지 못했어요, 잠시 후 다시 시도해 주세요")
                    )
                case .otherToppingSelected, .otherTextSelected:
                    break
                }
            }
        }
    }

    private var canvasBoard: some View {
        ZStack {
            Color.gray100
            CanvasContentView(
                content: CanvasStore.CanvasContent(
                    background: store.state.background,
                    images: store.state.activeToppings.map(\.canvasImage),
                    texts: store.state.activeTexts.map { $0.canvasText(placement: $0.placement) }
                )
            )
        }
        .canvasBoardFrame()
    }

    private var backgroundImageSourceBinding: Binding<BackgroundImagePickerStore.PhotoSource?> {
        Binding(
            get: { store.state.backgroundImageSource },
            set: { source in
                if source == nil {
                    store.send(.backgroundImageFlowDismissed)
                }
            }
        )
    }
}
