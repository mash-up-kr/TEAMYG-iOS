//
//  ToppingAddFlowView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import SwiftUI
import UIComponent

struct ToppingAddFlowView: View {
    @State private var store: ToppingAddStore
    @State private var toasts: [YGToastItem] = []
    @State private var areaSelectionToasts: [YGToastItem] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let toppingRenderer: CanvasToppingRenderer

    init(
        store: ToppingAddStore,
        toppingRenderer: CanvasToppingRenderer
    ) {
        _store = State(initialValue: store)
        self.toppingRenderer = toppingRenderer
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
        .environment(\.canvasToppingRenderer, toppingRenderer)
        .task {
            store.send(.screenAppeared)
        }
        .onDisappear {
            store.send(.screenDisappeared)
        }
        // 한 플로우 안에서 화면이 바뀌므로 onAppear 대신 화면이 바뀔 때마다 알린다.
        .onChange(of: store.state.screen, initial: true) {
            store.send(.screenChanged)
        }
        // 후보 추출·빈 누끼 생성 같은 짧은 작업은 전용 로딩 화면 대신 현재 화면 위 오버레이로.
        .ygLoading(store.state.extractionState == .extracting)
        .ygPopup(
            isPresented: store.binding(\.isAddPhotoQuitPopupPresented) {
                .quitPopupVisibilityChanged(.addPhoto, $0)
            },
            title: ToppingAddStore.QuitConfirmation.addPhoto.title,
            description: canvasQuitPopupDescription,
            secondaryTitle: "그만두기",
            primaryTitle: ToppingAddStore.QuitConfirmation.addPhoto.continueTitle,
            secondaryAction: { store.send(.quitConfirmed) }
        )
        .ygPopup(
            isPresented: store.binding(\.isEditPhotoQuitPopupPresented) {
                .quitPopupVisibilityChanged(.editPhoto, $0)
            },
            title: ToppingAddStore.QuitConfirmation.editPhoto.title,
            description: canvasQuitPopupDescription,
            secondaryTitle: "그만두기",
            primaryTitle: ToppingAddStore.QuitConfirmation.editPhoto.continueTitle,
            secondaryAction: { store.send(.quitConfirmed) }
        )
        .ygToastOverlay($toasts)
        .task {
            for await event in store.eventStream() {
                switch event {
                case .saveFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "사진을 저장하지 못했어요, 잠시 후 다시 시도해 주세요")
                    )
                case .detectionFailed:
                    areaSelectionToasts = [
                        YGToastItem(kind: .warning, message: "대상 감지에 실패했어요, 영역을 직접 선택해 주세요")
                    ]
                case .photoUnavailable:
                    toasts.append(
                        YGToastItem(kind: .error, message: "사진을 불러오지 못했어요, 다시 시도해 주세요")
                    )
                case .dismissRequested:
                    dismiss()
                }
            }
        }
        .onCameraScenePhaseChange(
            becameActive: { store.send(.sceneBecameActive) },
            enteredBackground: { store.send(.sceneEnteredBackground) }
        )
    }

    @ViewBuilder
    private var cameraFlow: some View {
        switch store.state.screen {
        case .camera, .cameraConfirmation:
            CameraCaptureScreen(
                isConfirming: store.state.screen == .cameraConfirmation,
                dateText: store.state.canvasDateText,
                weekdayText: store.state.canvasWeekdayText,
                cameraState: store.cameraState,
                previewSource: store.previewSource,
                isNextEnabled: store.cameraState.hasCapture,
                showsToast: store.state.showsToast,
                onToastDismissed: { store.send(.toastDismissed) },
                onAction: { store.send(.camera($0)) }
            )

        case .cameraPermissionError:
            CameraErrorScreen.permissionDenied(
                onCloseTap: { store.send(.closeTapped) },
                onSettingsTap: openURL.openAppSettings
            )

        case .cameraUnavailable:
            CameraErrorScreen.unavailable(
                onCloseTap: { store.send(.closeTapped) },
                onRetryTap: { store.send(.cameraRetryTapped) }
            )

        default:
            analysisFlow
        }
    }

    private var galleryFlow: some View {
        ZStack {
            AlbumView(
                makeAlbumPickerStore: { store.albumPickerStore(isLimited: $0) },
                onCloseTap: { store.send(.closeTapped) }
            )

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
                onCancelTap: { store.send(.analysisCancelled) }
            )

        case .candidateSelection:
            if let analysis = store.state.analysis {
                ToppingCandidateSelectionView(
                    photo: analysis.photo,
                    candidates: analysis.candidates,
                    onBackTap: { store.send(.candidateSelectionBackTapped) },
                    onCloseTap: { store.send(.closeTapped) },
                    onCandidateTap: { store.send(.candidateTapped(normalizedPoint: $0)) },
                    onManualSelectionTap: { store.send(.manualSelectionTapped) }
                )
            }

        case .areaSelection:
            if let cutoutEditCanvas = store.state.cutoutEditCanvas {
                ToppingAreaSelectionView(
                    canvas: cutoutEditCanvas,
                    brush: store.state.maskEditor.brush,
                    canUndo: store.state.maskEditor.canUndo,
                    canRedo: store.state.maskEditor.canRedo,
                    onUndoTap: { store.send(.maskUndoTapped) },
                    onRedoTap: { store.send(.maskRedoTapped) },
                    onBrushModeSelect: { store.send(.brushModeSelected($0)) },
                    onBrushDiameterChange: { store.send(.brushDiameterChanged($0)) },
                    onStrokeEnd: { store.send(.brushStrokeEnded($0)) },
                    isNextEnabled: store.state.cutoutHasArea,
                    onBackTap: { store.send(.areaSelectionBackTapped) },
                    onCloseTap: { store.send(.closeTapped) },
                    onNextTap: { store.send(.areaSelectionConfirmed) },
                    toasts: $areaSelectionToasts
                )
            }

        case .placement:
            if let extractedTopping = store.state.extractedTopping {
                ToppingPlacementBorderView(
                    canvasContent: store.state.canvasContent,
                    topping: extractedTopping,
                    silhouette: store.state.borderSilhouette?.image,
                    border: store.state.border,
                    editor: store.state.placementEditor,
                    isBorderPanelExpanded: store.state.isBorderPanelExpanded,
                    isSaving: store.state.saveState == .saving,
                    onCanvasResize: { store.send(.placementCanvasResized($0)) },
                    onTransform: { store.send(.placementTransformed($0)) },
                    onBorderWidthChange: { store.send(.borderWidthChanged($0)) },
                    onBorderColorSelect: { store.send(.borderColorSelected($0)) },
                    onBorderPanelExpandTap: { store.send(.borderPanelExpandTapped) },
                    onBorderPanelClose: { store.send(.borderPanelClosed) },
                    onBackTap: { store.send(.placementBackTapped) },
                    onCloseTap: { store.send(.closeTapped) },
                    onConfirmTap: { store.send(.placementConfirmed) }
                )
            }

        default:
            EmptyView()
        }
    }
}
