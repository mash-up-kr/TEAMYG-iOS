//
//  ToppingAddFlowView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import CanvasDomain
import SwiftUI
import UIComponent

struct ToppingAddFlowView: View {
    @State private var store: ToppingAddStore
    @State private var toasts: [YGToastItem] = []
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    private let makeAlbumPickerStore: AlbumPickerStoreFactory

    init(store: ToppingAddStore, makeAlbumPickerStore: @escaping AlbumPickerStoreFactory) {
        _store = State(initialValue: store)
        self.makeAlbumPickerStore = makeAlbumPickerStore
    }

    var body: some View {
        Group {
            switch store.state.photoSource {
            case .camera:
                cameraFlow
            case .gallery:
                galleryFlow
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            store.send(.screenAppeared)
        }
        .onDisappear {
            store.send(.screenDisappeared)
        }
        // `.inactive` 는 권한 다이얼로그·알림 배너·앱 스위처 등에서도 흔히 발생한다.
        // 여기서 세션을 끄면 껐다 켜기가 잦아져 최초 권한 요청 플로우가 끊기므로 `.background` 만 처리한다.
        // (백그라운드 진입 시엔 iOS 가 캡처 세션을 어차피 중단시킨다.)
        .ygToastOverlay($toasts)
        .onChange(of: store.state.saveState) { _, saveState in
            guard saveState == .failed else { return }
            toasts.append(
                YGToastItem(kind: .error, message: "토핑을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.")
            )
            store.send(.saveErrorDismissed)
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
    private var cameraFlow: some View {
        switch store.state.screen {
        case .camera:
            ToppingCameraView(
                dateText: store.state.canvasDateText,
                weekdayText: store.state.canvasWeekdayText,
                flashMode: store.state.flashMode,
                isFlashControlEnabled: store.state.isFlashControlEnabled,
                isCameraReady: store.state.isCameraReady,
                showsToast: store.state.showsToast,
                previewSource: store.previewSource,
                onToastDismissed: { store.send(.toastDismissed) },
                onFlashTap: { store.send(.flashTapped) },
                onShutterTap: { store.send(.shutterTapped(viewFinderRegion: $0)) },
                onSwitchCameraTap: { store.send(.cameraPositionTapped) }
            )

        case .cameraConfirmation:
            ToppingCameraConfirmationView(
                previewFrame: store.state.cameraPreviewFrame,
                photoData: store.state.capturedPhotoData,
                viewFinderRegion: store.state.capturedViewFinderRegion,
                isRetakeEnabled: store.state.isRetakeEnabled,
                isNextEnabled: store.state.isNextEnabled,
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

        default:
            analysisFlow
        }
    }

    /// 일반 사진은 확인 화면(C-102-Confirm)을 거치고, 최근 업로드 누끼는 곧장 테두리 편집으로 간다.
    private func albumPickerStore(isLimited: Bool) -> AlbumPickerStore {
        makeAlbumPickerStore(isLimited, confirmGalleryPhoto, confirmRecentUpload)
    }

    private func confirmGalleryPhoto(_ assetIdentifier: String) {
        store.send(.galleryPhotoConfirmed(assetIdentifier: assetIdentifier))
    }

    private func confirmRecentUpload(_ upload: StoredImage) {
        store.send(.recentUploadConfirmed(upload))
    }

    private var galleryFlow: some View {
        ZStack {
            AlbumView(makeAlbumPickerStore: albumPickerStore(isLimited:))

            if store.state.screen.isAnalysisScreen {
                analysisFlow
            }
        }
    }

    @ViewBuilder
    private var analysisFlow: some View {
        switch store.state.screen {
        case .analysisLoading:
            ToppingAnalysisLoadingView(
                onCancelTap: {
                    store.send(.analysisCancelled)
                    dismiss()
                }
            )

        case .analysisError:
            ToppingAnalysisErrorView(
                onCloseTap: { store.send(.analysisErrorClosed) }
            )

        case .candidateSelection:
            if let analysis = store.state.analysis {
                ToppingCandidateSelectionView(
                    photo: analysis.photo,
                    candidates: analysis.candidates,
                    onBackTap: { store.send(.candidateSelectionBackTapped) },
                    onCandidateTap: { store.send(.candidateTapped(normalizedPoint: $0)) }
                )
            }

        case .cutoutResult:
            if let extractedTopping = store.state.extractedTopping {
                ToppingCutoutResultView(
                    topping: extractedTopping,
                    onCloseTap: { store.send(.cutoutResultClosed) },
                    onPhotoEditTap: { store.send(.photoEditTapped) },
                    onNextTap: { store.send(.cutoutConfirmed) }
                )
            }

        case .manualCutout:
            if let extractedTopping = store.state.extractedTopping {
                ToppingManualCutoutView(
                    topping: extractedTopping,
                    brush: store.state.maskEditor.brush,
                    canUndo: store.state.maskEditor.canUndo,
                    canRedo: store.state.maskEditor.canRedo,
                    onUndoTap: { store.send(.maskUndoTapped) },
                    onRedoTap: { store.send(.maskRedoTapped) },
                    onBrushModeSelect: { store.send(.brushModeSelected($0)) },
                    onBrushDiameterChange: { store.send(.brushDiameterChanged($0)) },
                    onStrokeEnd: { store.send(.brushStrokeEnded($0)) },
                    onCloseTap: { store.send(.manualCutoutClosed) },
                    onConfirmTap: { store.send(.manualCutoutConfirmed) }
                )
            }

        case .borderEdit:
            if let extractedTopping = store.state.extractedTopping {
                ToppingBorderEditView(
                    topping: extractedTopping.image,
                    silhouette: store.state.borderSilhouette?.image,
                    border: store.state.borderEditor.border,
                    canUndo: store.state.borderEditor.canUndo,
                    canRedo: store.state.borderEditor.canRedo,
                    onUndoTap: { store.send(.borderUndoTapped) },
                    onRedoTap: { store.send(.borderRedoTapped) },
                    onWidthChange: { store.send(.borderWidthChanged($0)) },
                    onWidthEditingChange: { store.send(.borderWidthEditingChanged($0)) },
                    onColorSelect: { store.send(.borderColorSelected($0)) },
                    showsAreaTab: store.state.cutoutPath != .recentUpload,
                    onAreaTabTap: { store.send(.borderAreaTabTapped) },
                    onCloseTap: { store.send(.borderEditClosed) },
                    onConfirmTap: { store.send(.borderConfirmed) }
                )
            }

        case .placement:
            if let extractedTopping = store.state.extractedTopping {
                ToppingPlacementView(
                    canvasContent: store.state.canvasContent,
                    topping: extractedTopping,
                    silhouette: store.state.borderSilhouette?.image,
                    borderColor: store.state.borderEditor.border.color.strokeColor,
                    editor: store.state.placementEditor,
                    isSaving: store.state.saveState == .saving,
                    onCanvasResize: { store.send(.placementCanvasResized($0)) },
                    onMove: { store.send(.placementMoved(translation: $0)) },
                    onScale: { store.send(.placementScaled(factor: $0)) },
                    onRotate: { store.send(.placementRotated(degrees: $0)) },
                    onCloseTap: { store.send(.placementClosed) },
                    onConfirmTap: { store.send(.placementConfirmed) }
                )
            }

        default:
            EmptyView()
        }
    }
}
