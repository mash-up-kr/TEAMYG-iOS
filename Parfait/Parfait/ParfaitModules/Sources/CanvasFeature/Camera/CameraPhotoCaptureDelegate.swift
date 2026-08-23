//
//  CameraPhotoCaptureDelegate.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/20/26.
//

import AVFoundation
import Foundation

final class CameraPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completionLock = NSLock()
    private var completion: (@Sendable (Data?) -> Void)?

    func setCompletion(_ completion: @escaping @Sendable (Data?) -> Void) {
        completionLock.withLock { self.completion = completion }
    }

    func cancel() {
        finish(with: nil)
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
