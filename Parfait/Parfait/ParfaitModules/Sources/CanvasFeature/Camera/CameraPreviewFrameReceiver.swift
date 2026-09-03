//
//  CameraPreviewFrameReceiver.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import AVFoundation
import Foundation
import VideoToolbox

final class CameraPreviewFrameReceiver: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// 프리즈 프레임은 촬영 직후 확인 화면에 잠깐 띄우는 플레이스홀더라 화면 크기면 충분하다.
    /// 캡처 해상도 그대로 두면 분석이 끝날 때까지 수십 MB 가 State 에 남는다.
    private static let maximumFrameLongEdge: CGFloat = 1280

    private let frameLock = NSLock()
    private var latestPixelBuffer: CVPixelBuffer?
    private var acceptsFrames = false

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameLock.withLock {
            guard acceptsFrames else { return }
            latestPixelBuffer = pixelBuffer
        }
    }

    func latestFrame() -> CameraPreviewFrame? {
        let pixelBuffer = frameLock.withLock { latestPixelBuffer }
        guard let pixelBuffer else { return nil }

        var image: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
        guard status == noErr, let image else { return nil }
        return CameraPreviewFrame(image: image.downscaled(longEdge: Self.maximumFrameLongEdge))
    }

    func pauseAndClear() {
        frameLock.withLock {
            acceptsFrames = false
            latestPixelBuffer = nil
        }
    }

    func resume() {
        frameLock.withLock {
            acceptsFrames = true
        }
    }
}
