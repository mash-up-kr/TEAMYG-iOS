//
//  CameraPhotoCaptureDelegate.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/20/26.
//

import AVFoundation
import Foundation

/// `didFinishProcessingPhoto` / `didFinishCaptureFor` 가 둘 다 불릴 수 있어
/// 완료 콜백이 정확히 한 번만 나가도록 잠금으로 보장한다.
final class CameraPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completionLock = NSLock()
    private var completion: (@Sendable (Data?) -> Void)?

    init(completion: @escaping @Sendable (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil else {
            finish(with: nil)
            return
        }
        finish(with: photo.fileDataRepresentation())
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        finish(with: nil)
    }

    private func finish(with photoData: Data?) {
        let pendingCompletion = completionLock.withLock {
            let storedCompletion = completion
            completion = nil
            return storedCompletion
        }
        pendingCompletion?(photoData)
    }
}
