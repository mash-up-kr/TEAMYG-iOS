//
//  ToppingAddStore+State.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/20/26.
//

import CanvasDomain
import CoreGraphics
import Foundation

extension ToppingAddStore {
    struct State: Equatable, Sendable {
        let canvasDate: CalendarDate
        let photoSource: PhotoSource
        /// 배치 화면 뒤에 깔리는 오늘 캔버스. 10초마다 서버 값으로 갈아 끼운다.
        var canvasContent: CanvasStore.CanvasContent?
        var screen: Screen
        var analysis: PhotoAnalysis?
        var extractedTopping: ExtractedTopping?
        var cutoutEditCanvas: CutoutEditCanvas?
        var border = ToppingBorder()
        var borderSilhouette: BorderSilhouette?
        var maskEditor = ToppingMaskEditor()
        var placementEditor = ToppingPlacementEditor()
        var isRecentUpload = false
        /// 지금 누끼에 포함된 영역이 있는지. 비어 있으면 C-104 다음(→C-105)을 막는다.
        var cutoutHasArea = true
        var showsToast = true
        var saveState: SaveState = .idle
        var extractionState: ExtractionState = .idle
        var quitConfirmation: QuitConfirmation?
        var isBorderPanelExpanded = true

        init(
            canvasDate: CalendarDate,
            photoSource: PhotoSource,
            canvasContent: CanvasStore.CanvasContent? = nil
        ) {
            self.canvasDate = canvasDate
            self.photoSource = photoSource
            self.canvasContent = canvasContent
            screen = photoSource.entryScreen
        }

        var isAddPhotoQuitPopupPresented: Bool {
            quitConfirmation == .addPhoto
        }

        var isEditPhotoQuitPopupPresented: Bool {
            quitConfirmation == .editPhoto
        }

        var borderRenderLongEdge: CGFloat {
            placementEditor.placement.longSide(in: placementEditor.canvasSize)
        }

        var canvasDateText: String {
            "\(canvasDate.monthName) \(canvasDate.day)"
        }

        var canvasWeekdayText: String {
            "(\(canvasDate.weekdayName))"
        }
    }

    enum Intent {
        case screenAppeared
        case screenDisappeared
        case sceneBecameActive
        case sceneEnteredBackground
        case canvasRefreshTicked
        case toastDismissed
        case flashTapped
        case cameraPositionTapped
        case shutterTapped(viewFinderRegion: ViewFinderRegion?)
        case retakeTapped
        case photoConfirmed
        case galleryPhotoConfirmed(assetIdentifier: String)
        case recentUploadConfirmed(StoredImage)
        case cameraRetryTapped
        case settingsTapped
        case analysisCancelled
        case candidateTapped(normalizedPoint: CGPoint)
        case candidateSelectionBackTapped
        case brushModeSelected(ToppingBrushMode)
        case brushDiameterChanged(Double)
        case brushStrokeEnded(ToppingBrushStroke)
        case maskUndoTapped
        case maskRedoTapped
        case areaSelectionBackTapped
        case areaSelectionConfirmed
        case borderWidthChanged(Double)
        case borderColorSelected(ToppingBorderColor)
        case borderPanelExpandTapped
        case borderPanelClosed
        case placementCanvasResized(CGSize)
        case placementTransformed(ToppingTransformDraft)
        case placementBackTapped
        case placementConfirmed
        case closeTapped
        case quitPopupVisibilityChanged(QuitConfirmation, Bool)
        case quitConfirmed(QuitConfirmation)
    }

    enum Event: Sendable {
        case saveFailed
        case detectionFailed
        case photoUnavailable
        case dismissRequested
    }

    enum QuitConfirmation: Equatable, Sendable {
        case addPhoto
        case editPhoto

        var title: String {
            switch self {
            case .addPhoto: "사진 추가를 그만둘까요?"
            case .editPhoto: "사진 편집을 그만둘까요?"
            }
        }

        var continueTitle: String {
            switch self {
            case .addPhoto: "계속 추가"
            case .editPhoto: "계속 편집"
            }
        }
    }

    enum PhotoSource: Equatable, Sendable {
        case camera
        case gallery

        var entryScreen: Screen {
            switch self {
            case .camera: .camera
            case .gallery: .gallery
            }
        }

        var confirmScreen: Screen {
            switch self {
            case .camera: .cameraConfirmation
            case .gallery: .gallery
            }
        }
    }

    enum Screen: Equatable, Sendable {
        case camera
        case cameraConfirmation
        case cameraPermissionError
        case cameraUnavailable
        case gallery
        case analysisLoading
        case candidateSelection
        case areaSelection
        case placement

        var isCameraError: Bool {
            self == .cameraPermissionError || self == .cameraUnavailable
        }

        var needsRunningCamera: Bool {
            self == .camera || isCameraError
        }

        var isAnalysisScreen: Bool {
            switch self {
            case .analysisLoading, .candidateSelection, .areaSelection, .placement:
                true
            default: false
            }
        }
    }
}

extension ToppingAddStore {
    /// 배치 확정 후 업로드·저장 진행 상태. 실패 화면 시안이 없어 토스트로 알리고 배치 화면에 머문다.
    /// **실패는 여기 담지 않는다** — 일회성 알림이라 이벤트 채널로 보낸다 (`docs/mvi.md`).
    enum SaveState: Equatable, Sendable {
        case idle
        case saving
    }

    /// 후보 추출·빈 누끼 생성처럼 짧은 로컬 작업의 진행 상태.
    /// 전용 로딩 화면(C-103-Loading)이 아니라 현재 화면 위 `.ygLoading` 오버레이로 보여준다 —
    /// 수백 ms 작업에 화면 전체가 갈리는 flash 를 막는다.
    enum ExtractionState: Equatable, Sendable {
        case idle
        case extracting
    }
}
