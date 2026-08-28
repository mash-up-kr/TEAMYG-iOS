//
//  BackgroundImagePickerView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CanvasDomain
import SwiftUI
import UIComponent

struct BackgroundImagePickerView: View {
    @State private var store: BackgroundImagePickerStore
    @State private var toasts: [YGToastItem] = []
    @Environment(\.scenePhase) private var scenePhase

    private let makeAlbumPickerStore: AlbumPickerStoreFactory

    init(
        store: BackgroundImagePickerStore,
        makeAlbumPickerStore: @escaping AlbumPickerStoreFactory
    ) {
        _store = State(initialValue: store)
        self.makeAlbumPickerStore = makeAlbumPickerStore
    }

    var body: some View {
        ZStack {
            content

            if store.state.isPreparingImage {
                Color.black25
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.whiteFixed)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ygToastOverlay($toasts)
        .task {
            store.send(.screenAppeared)
            for await event in store.eventStream() {
                switch event {
                case .imagePreparationFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "사진을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
                    )
                }
            }
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
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state.screen {
        case .camera:
            ToppingCameraView(
                dateText: store.state.dateText,
                weekdayText: store.state.weekdayText,
                flashMode: store.cameraState.flashMode,
                isFlashControlEnabled: store.cameraState.isFlashControlEnabled,
                isCameraReady: store.cameraState.isReady,
                showsToast: false,
                previewSource: store.previewSource,
                onToastDismissed: { store.send(.cameraGuideDismissed) },
                onFlashTap: { store.send(.flashTapped) },
                onShutterTap: { store.send(.shutterTapped(viewFinderRegion: $0)) },
                onSwitchCameraTap: { store.send(.cameraPositionTapped) }
            )

        case .cameraConfirmation:
            ToppingCameraConfirmationView(
                previewFrame: store.cameraState.previewFrame,
                photoData: store.cameraState.capturedPhotoData,
                viewFinderRegion: store.cameraState.capturedViewFinderRegion,
                isRetakeEnabled: store.cameraState.isRetakeEnabled,
                isNextEnabled: store.cameraState.hasCapture && !store.state.isPreparingImage,
                onRetakeTap: { store.send(.retakeTapped) },
                onNextTap: { store.send(.photoConfirmed) }
            )

        case .cameraPermissionError:
            ToppingErrorView(
                title: "카메라 권한이 없어요",
                message: "설정에서 카메라 권한을 허용해 주세요",
                actionTitle: "설정으로 이동",
                onActionTap: { store.send(.settingsTapped) }
            )

        case .cameraUnavailable:
            ToppingErrorView(
                title: "카메라를 사용할 수 없어요",
                message: "잠시 후 다시 시도해 주세요",
                actionTitle: "다시 시도",
                onActionTap: { store.send(.cameraRetryTapped) }
            )

        case .gallery:
            AlbumView(
                makeAlbumPickerStore: { isLimited in
                    // 최근 업로드는 알파 누끼라 JPEG 배경으로 만들면 투명 영역이 검게 굳는다.
                    makeAlbumPickerStore(
                        isLimited,
                        false,
                        confirmGalleryPhoto,
                        confirmRecentUpload
                    )
                },
                showsSelectionGuide: false
            )
        }
    }

    private func confirmGalleryPhoto(_ assetIdentifier: String) {
        store.send(.galleryPhotoConfirmed(assetIdentifier: assetIdentifier))
    }

    private func confirmRecentUpload(_ upload: StoredImage) {
        store.send(.recentUploadConfirmed(upload))
    }
}
