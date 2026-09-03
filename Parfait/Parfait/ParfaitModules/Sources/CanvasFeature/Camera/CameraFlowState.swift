//
//  CameraFlowState.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

import Foundation

/// C-101 카메라의 상태. 두 흐름(토핑 추가·배경 편집)이 같은 값을 쓴다.
struct CameraFlowState: Equatable, Sendable {
    var phase: CameraPhase = .idle
    var flashMode: CameraFlashMode = .off
    var position: CameraPosition = .back
    var capturePhase: PhotoCapturePhase = .idle
    var capturedViewFinderRegion: ViewFinderRegion?
    var isSwitching = false
    /// 촬영이 끝나는 대로 다음 단계(분석·배경 준비)로 넘길지. 프리즈 프레임 상태에서 `다음` 을 누른 경우.
    var wantsHandoff = false

    var isReady: Bool {
        phase == .running && !isSwitching && capturePhase == .idle
    }

    /// 전면 카메라에는 플래시가 없다.
    var isFlashControlEnabled: Bool {
        position == .back
    }

    var capturedPhotoData: Data? {
        guard case .ready(_, let photoData) = capturePhase else { return nil }
        return photoData
    }

    var previewFrame: CameraPreviewFrame? {
        switch capturePhase {
        case .processing(let previewFrame), .ready(let previewFrame, _):
            previewFrame
        case .idle:
            nil
        }
    }

    var isRetakeEnabled: Bool {
        if case .ready = capturePhase { true } else { false }
    }

    var hasCapture: Bool {
        capturePhase != .idle
    }
}

enum CameraPhase: Equatable, Sendable {
    case idle
    case preparing
    case running
    case permissionDenied
    case unavailable
}

enum PhotoCapturePhase: Equatable, Sendable {
    case idle
    case processing(previewFrame: CameraPreviewFrame?)
    case ready(previewFrame: CameraPreviewFrame?, photoData: Data)
}

/// 카메라가 올려 보내는 사건. 화면 전이는 흐름마다 달라 Store 가 각자 해석한다.
enum CameraFlowEvent: Sendable {
    case permissionDenied
    case unavailable
    /// 세션이 떴다. 에러 화면에 머물러 있었다면 카메라로 되돌린다.
    case running
    /// 프리즈 프레임이 준비됐다 — 셔터 직후 확인 화면을 먼저 띄울 수 있다.
    case freezeFrameReady
    case captureFinished(photoData: Data, viewFinderRegion: ViewFinderRegion?, wantsHandoff: Bool)
    case captureFailed
    /// 촬영 중 세션이 중단됐다 (백그라운드 진입 등).
    case captureAborted
}
