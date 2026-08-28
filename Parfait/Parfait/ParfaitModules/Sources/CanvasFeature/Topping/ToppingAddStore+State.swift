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
        var maskEditor = ToppingMaskEditor()
        var placementEditor = ToppingPlacementEditor()
        var cutoutPath: CutoutPath = .automatic
        var showsToast = true
        var saveState: SaveState = .idle

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
        case cutoutResultClosed
        case photoEditTapped
        case cutoutConfirmed
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
        case placementMoved(translation: CGSize)
        case placementScaled(factor: Double)
        case placementRotated(degrees: Double)
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
}
