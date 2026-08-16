//
//  CameraSession.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import AVFoundation
import Foundation
import UIKit

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

actor CameraSession {
    nonisolated let previewSource: any CameraPreviewSource

    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var cameraPosition: CameraPosition = .back
    private var photoCaptureDelegate: CameraPhotoCaptureDelegate?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservers: [NSKeyValueObservation] = []
    private var isConfigured = false
    /// 지금까지 처리한 켜기/끄기 요청 중 가장 최신 번호. 이보다 낮은 번호는 늦게 도착한 요청이므로 버린다.
    private var latestGeneration = 0

    init() {
        previewSource = DefaultCameraPreviewSource(captureSession: captureSession)
    }

    func authorizationStatus() -> CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }

    func requestAuthorization() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func start(generation: Int) -> Bool {
        guard generation >= latestGeneration else { return false }
        latestGeneration = generation

        if !isConfigured, !configureSession(position: cameraPosition) {
            return false
        }

        guard !captureSession.isRunning else { return true }
        captureSession.startRunning()
        guard captureSession.isRunning else { return false }

        if let device = videoInput?.device {
            updateRotationCoordinator(for: device)
        }
        return true
    }

    func stop(generation: Int) {
        guard generation >= latestGeneration else { return }
        latestGeneration = generation

        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
    }

    func switchCamera() -> CameraPosition? {
        let nextPosition: CameraPosition = cameraPosition == .back ? .front : .back
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if let videoInput {
            captureSession.removeInput(videoInput)
        }

        guard let nextInput = makeVideoInput(position: nextPosition), captureSession.canAddInput(nextInput) else {
            if let videoInput, captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            return nil
        }

        captureSession.addInput(nextInput)
        videoInput = nextInput
        cameraPosition = nextPosition
        updateRotationCoordinator(for: nextInput.device)
        return nextPosition
    }

    func capturePhoto(_ requestedFlashMode: CameraFlashMode) async -> Data? {
        guard photoCaptureDelegate == nil else { return nil }

        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(requestedFlashMode.avFoundationMode) {
            settings.flashMode = requestedFlashMode.avFoundationMode
        }

        return await withCheckedContinuation { continuation in
            let delegate = CameraPhotoCaptureDelegate { [weak self] photoData in
                continuation.resume(returning: photoData)
                Task { await self?.clearPhotoCaptureDelegate() }
            }
            photoCaptureDelegate = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configureSession(position: CameraPosition) -> Bool {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.sessionPreset = .photo

        guard let input = makeVideoInput(position: position),
              captureSession.canAddInput(input),
              captureSession.canAddOutput(photoOutput) else { return false }

        captureSession.addInput(input)
        captureSession.addOutput(photoOutput)
        videoInput = input
        isConfigured = true
        return true
    }

    private func makeVideoInput(position: CameraPosition) -> AVCaptureDeviceInput? {
        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition) else {
            return nil
        }
        return try? AVCaptureDeviceInput(device: device)
    }

    private func updateRotationCoordinator(for device: AVCaptureDevice) {
        let previewLayer = captureSession.connections.compactMap(\.videoPreviewLayer).first
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        rotationObservers.removeAll()

        updatePreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
        updateCaptureRotation(coordinator.videoRotationAngleForHorizonLevelCapture)

        rotationObservers.append(
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { [weak self] _, change in
                guard let self, let rotationAngle = change.newValue else { return }
                Task { await self.updatePreviewRotation(rotationAngle) }
            }
        )
        rotationObservers.append(
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: .new) { [weak self] _, change in
                guard let self, let rotationAngle = change.newValue else { return }
                Task { await self.updateCaptureRotation(rotationAngle) }
            }
        )
    }

    private func updatePreviewRotation(_ rotationAngle: CGFloat) {
        let previewSource = previewSource
        Task { @MainActor in
            previewSource.applyPreviewRotationAngle(rotationAngle)
        }
    }

    private func updateCaptureRotation(_ rotationAngle: CGFloat) {
        guard let connection = photoOutput.connection(with: .video),
              connection.isVideoRotationAngleSupported(rotationAngle) else { return }
        connection.videoRotationAngle = rotationAngle
    }

    private func clearPhotoCaptureDelegate() {
        photoCaptureDelegate = nil
    }
}

private final class CameraPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
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

extension CameraFlashMode {
    var avFoundationMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: .off
        case .enabled: .on
        }
    }
}

extension ToppingAddStore.Dependencies {
    @MainActor
    public static func live(
        onFlowClosed: @escaping @MainActor @Sendable () async -> Void
    ) -> Self {
        let cameraSession = CameraSession()

        return Self(
            previewSource: cameraSession.previewSource,
            authorizationStatus: { await cameraSession.authorizationStatus() },
            requestAuthorization: { await cameraSession.requestAuthorization() },
            startCamera: { generation in await cameraSession.start(generation: generation) },
            stopCamera: { generation in await cameraSession.stop(generation: generation) },
            switchCamera: { await cameraSession.switchCamera() },
            capturePhoto: { await cameraSession.capturePhoto($0) },
            openSettings: {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                await UIApplication.shared.open(settingsURL)
            },
            onFlowClosed: onFlowClosed
        )
    }
}
