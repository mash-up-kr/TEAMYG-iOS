//
//  BackgroundImagePickerView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import SwiftUI
import UIComponent

struct BackgroundImagePickerView: View {
    @State private var store: BackgroundImagePickerStore
    @State private var toasts: [YGToastItem] = []

    private let makeAlbumPickerStore: AlbumPickerStoreFactory

    init(
        store: BackgroundImagePickerStore,
        makeAlbumPickerStore: @escaping AlbumPickerStoreFactory
    ) {
        _store = State(initialValue: store)
        self.makeAlbumPickerStore = makeAlbumPickerStore
    }

    var body: some View {
        content
            .ygLoading(store.state.isPreparingImage)
            .ygPopup(
                isPresented: store.binding(
                    \.showsQuitPopup,
                    BackgroundImagePickerStore.Intent.quitPopupVisibilityChanged
                ),
                title: "배경 변경을 그만둘까요?",
                description: "지금까지 진행한 내용은 저장되지 않아요.\n정말 그만두시겠어요?",
                secondaryTitle: "그만두기",
                primaryTitle: "계속 편집",
                secondaryAction: { store.send(.quitConfirmed) }
            )
            .toolbar(.hidden, for: .navigationBar)
            .ygToastOverlay($toasts)
            .task {
                store.send(.screenAppeared)
                for await event in store.eventStream() {
                    switch event {
                    case .imagePreparationFailed:
                        toasts.append(
                            YGToastItem(kind: .error, message: "사진을 불러오지 못했어요, 잠시 후 다시 시도해 주세요")
                        )
                    }
                }
            }
            .onDisappear {
                store.send(.screenDisappeared)
            }
            .onCameraScenePhaseChange(
                becameActive: { store.send(.sceneBecameActive) },
                enteredBackground: { store.send(.sceneEnteredBackground) }
            )
    }

    @ViewBuilder
    private var content: some View {
        switch store.state.screen {
        case .camera, .cameraConfirmation:
            CameraCaptureScreen(
                isConfirming: store.state.screen == .cameraConfirmation,
                dateText: store.state.dateText,
                weekdayText: store.state.weekdayText,
                cameraState: store.cameraState,
                previewSource: store.previewSource,
                isNextEnabled: store.cameraState.hasCapture && !store.state.isPreparingImage,
                onAction: { store.send(.camera($0)) }
            )

        case .cameraPermissionError:
            CameraErrorScreen.permissionDenied(
                onCloseTap: { store.send(.closeTapped) },
                onSettingsTap: { store.send(.settingsTapped) }
            )

        case .cameraUnavailable:
            CameraErrorScreen.unavailable(
                onCloseTap: { store.send(.closeTapped) },
                onRetryTap: { store.send(.cameraRetryTapped) }
            )

        case .gallery:
            AlbumView(
                makeAlbumPickerStore: { isLimited in
                    // 최근 업로드는 알파 누끼라 JPEG 배경으로 만들면 투명 영역이 검게 굳는다 —
                    // 핸들러를 주지 않아 최근 업로드 섹션을 감춘다.
                    makeAlbumPickerStore(isLimited, confirmGalleryPhoto, nil)
                },
                showsSelectionGuide: false,
                onCloseTap: { store.send(.closeTapped) }
            )
        }
    }

    private func confirmGalleryPhoto(_ assetIdentifier: String) {
        store.send(.galleryPhotoConfirmed(assetIdentifier: assetIdentifier))
    }
}
