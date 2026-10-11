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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    private static let quitPopupDescription = "지금까지 진행한 내용은 저장되지 않아요.\n정말 그만두시겠어요?"

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
        // 후보 추출·빈 누끼 생성 같은 짧은 작업은 전용 로딩 화면 대신 현재 화면 위 오버레이로.
        .ygLoading(store.state.extractionState == .extracting)
        .ygPopup(
            isPresented: store.binding(\.isAddPhotoQuitPopupPresented) {
                .quitPopupVisibilityChanged(.addPhoto, $0)
            },
            title: ToppingAddStore.QuitConfirmation.addPhoto.title,
            description: Self.quitPopupDescription,
            secondaryTitle: "그만두기",
            primaryTitle: ToppingAddStore.QuitConfirmation.addPhoto.continueTitle,
            secondaryAction: { store.send(.quitConfirmed(.addPhoto)) }
        )
        .ygPopup(
            isPresented: store.binding(\.isEditPhotoQuitPopupPresented) {
                .quitPopupVisibilityChanged(.editPhoto, $0)
            },
            title: ToppingAddStore.QuitConfirmation.editPhoto.title,
            description: Self.quitPopupDescription,
            secondaryTitle: "그만두기",
            primaryTitle: ToppingAddStore.QuitConfirmation.editPhoto.continueTitle,
            secondaryAction: { store.send(.quitConfirmed(.editPhoto)) }
        )
        .ygToastOverlay($toasts)
        .task {
            for await event in store.eventStream() {
                switch event {
                case .saveFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "토핑을 저장하지 못했어요, 잠시 후 다시 시도해 주세요")
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
        // `.inactive` 는 권한 다이얼로그·알림 배너·앱 스위처 등에서도 흔히 발생한다.
        // 여기서 세션을 끄면 껐다 켜기가 잦아져 최초 권한 요청 플로우가 끊기므로 `.background` 만 처리한다.
        // (백그라운드 진입 시엔 iOS 가 캡처 세션을 어차피 중단시킨다.)
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
        case .camera, .cameraConfirmation:
            CameraCaptureContainer(isConfirming: store.state.screen == .cameraConfirmation) {
                ToppingCameraView(
                    dateText: store.state.canvasDateText,
                    weekdayText: store.state.canvasWeekdayText,
                    flashMode: store.cameraState.flashMode,
                    isFlashControlEnabled: store.cameraState.isFlashControlEnabled,
                    isCameraReady: store.cameraState.isReady,
                    showsToast: store.state.showsToast,
                    previewSource: store.previewSource,
                    onToastDismissed: { store.send(.toastDismissed) },
                    onFlashTap: { store.send(.flashTapped) },
                    onShutterTap: { store.send(.shutterTapped(viewFinderRegion: $0)) },
                    onSwitchCameraTap: { store.send(.cameraPositionTapped) }
                )
            } confirmation: {
                ToppingCameraConfirmationView(
                    previewFrame: store.cameraState.previewFrame,
                    photoData: store.cameraState.capturedPhotoData,
                    viewFinderRegion: store.cameraState.capturedViewFinderRegion,
                    isRetakeEnabled: store.cameraState.isRetakeEnabled,
                    isNextEnabled: store.cameraState.hasCapture,
                    onRetakeTap: { store.send(.retakeTapped) },
                    onNextTap: { store.send(.photoConfirmed) },
                    onCloseTap: { store.send(.closeTapped) }
                )
            }

        case .cameraPermissionError:
            CameraErrorScreen(
                title: "카메라 권한이 없어요",
                message: "설정에서 카메라 권한을 허용해 주세요",
                buttonTitle: "설정으로 이동",
                action: { store.send(.settingsTapped) }
            )

        case .cameraUnavailable:
            CameraErrorScreen(
                title: "카메라를 사용할 수 없어요",
                message: "잠시 후 다시 시도해 주세요",
                buttonTitle: "다시 시도",
                action: { store.send(.cameraRetryTapped) }
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
                    onCandidateTap: { store.send(.candidateTapped(normalizedPoint: $0)) }
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
