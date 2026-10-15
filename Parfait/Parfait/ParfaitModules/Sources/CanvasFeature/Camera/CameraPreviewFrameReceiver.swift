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

    /// 가장 최근 프레임. 원본 해상도 그대로다.
    func latestFrame() -> CameraPreviewFrame? {
        let pixelBuffer = frameLock.withLock { latestPixelBuffer }
        guard let pixelBuffer else { return nil }

        var image: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
        guard status == noErr, let image else { return nil }
        return CameraPreviewFrame(image: image)
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
