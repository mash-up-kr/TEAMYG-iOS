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
        let canvasContent: CanvasStore.CanvasContent?
        var screen: Screen
        var galleryAssetIdentifier: String?
        var analysis: PhotoAnalysis?
        var extractedTopping: ExtractedTopping?
        var borderEditor = ToppingBorderEditor()
        var borderSilhouette: BorderSilhouette?
        var borderPreviewLongEdge: CGFloat = 0
        var maskEditor = ToppingMaskEditor()
        var placementEditor = ToppingPlacementEditor()
        var cutoutPath: CutoutPath = .automatic
        /// 지금 누끼에 포함된 영역이 있는지. 비어 있으면 C-104 확인(→C-105)을 막는다.
        var cutoutHasArea = true
        var showsToast = true
        var saveState: SaveState = .idle
        var extractionState: ExtractionState = .idle

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

        var borderRenderLongEdge: CGFloat {
            switch screen {
            case .placement:
                placementEditor.placement.longSide(in: placementEditor.canvasSize)
            default:
                borderPreviewLongEdge
            }
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
        case analysisErrorClosed
        case analysisRetryTapped
        case useWithoutEditTapped
        case cutoutResultClosed
        case photoEditTapped
        case cutoutConfirmed
        case borderPreviewLongEdgeChanged(CGFloat)
        case borderWidthChanged(Double)
        case borderWidthEditingChanged(Bool)
        case borderColorSelected(ToppingBorderColor)
        case borderUndoTapped
        case borderRedoTapped
        case borderEditClosed
        case borderAreaTabTapped
        case borderConfirmed
        case brushModeSelected(ToppingBrushMode)
        case brushDiameterChanged(Double)
        case brushStrokeEnded(ToppingBrushStroke)
        case maskUndoTapped
        case maskRedoTapped
        case manualCutoutClosed
        case manualCutoutConfirmed
        case placementCanvasResized(CGSize)
        case placementTransformed(ToppingTransformDraft)
        case placementClosed
        case placementConfirmed
    }

    enum Event: Sendable {
        case saveFailed
    }

    /// 누끼를 어떻게 만들었는지. C-105 의 X 목적지와 `영역` 탭 제공 여부가 갈린다
    /// (`topping_ui.md` §7.3).
    enum CutoutPath: Equatable, Sendable {
        case automatic
        case manual
        /// 최근 업로드에서 바로 C-105 로 온 경로. 원본 사진이 없어 영역 편집(C-104)으로 갈 수 없다.
        case recentUpload
        /// 분석 실패 후 "편집 없이 사용" — 원본 사진을 전부 제외된 빈 마스크로 C-104 부터 시작한다.
        /// C-104 닫기가 실패 화면(C-103-Error)으로 돌아가는 점이 `manual` 과 다르다.
        case withoutEdit

        /// 영역(C-104) 탭 제공 여부 — 최근 업로드만 원본 사진이 없어 불가.
        var allowsAreaEdit: Bool {
            self != .recentUpload
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
        case analysisError
        case candidateSelection
        case cutoutResult
        case manualCutout
        case borderEdit
        case placement

        var isCameraError: Bool {
            self == .cameraPermissionError || self == .cameraUnavailable
        }

        var needsRunningCamera: Bool {
            self == .camera || isCameraError
        }

        var isAnalysisScreen: Bool {
            switch self {
            case .analysisLoading, .analysisError, .candidateSelection, .cutoutResult,
                 .manualCutout, .borderEdit, .placement:
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
