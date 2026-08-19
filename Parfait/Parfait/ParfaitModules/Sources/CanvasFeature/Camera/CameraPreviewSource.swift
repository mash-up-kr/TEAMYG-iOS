//
//  CameraPreviewSource.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/20/26.
//

import AVFoundation

/// 촬영 파이프라인을 감춘 채 미리보기 레이어 연결만 뷰에 노출하는 통로.
protocol CameraPreviewSource: Sendable {
    @MainActor func connect(to target: any CameraPreviewTarget)
    @MainActor func applyPreviewRotationAngle(_ rotationAngle: CGFloat)
}

@MainActor
protocol CameraPreviewTarget: AnyObject {
    func setSession(_ session: AVCaptureSession)
}

struct DefaultCameraPreviewSource: CameraPreviewSource, @unchecked Sendable {
    private let captureSession: AVCaptureSession

    init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
    }

    @MainActor
    func connect(to target: any CameraPreviewTarget) {
        target.setSession(captureSession)
    }

    @MainActor
    func applyPreviewRotationAngle(_ rotationAngle: CGFloat) {
        guard let connection = captureSession.connections.first(where: { $0.videoPreviewLayer != nil }),
              connection.isVideoRotationAngleSupported(rotationAngle) else { return }
        connection.videoRotationAngle = rotationAngle
    }
}
