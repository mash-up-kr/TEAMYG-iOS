//
//  CameraSession.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import AVFoundation
import Foundation

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

    nonisolated func authorizationStatus() -> CameraAuthorization {
        CameraAuthorization(AVCaptureDevice.authorizationStatus(for: .video))
    }

    nonisolated func requestAuthorization() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func start(generation: Int) -> Bool {
        guard acceptsRequest(generation) else { return false }

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
        guard acceptsRequest(generation), captureSession.isRunning else { return }
        captureSession.stopRunning()
    }

    func switchCamera() -> CameraPosition? {
        let nextPosition = cameraPosition.flipped
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if let videoInput {
            captureSession.removeInput(videoInput)
        }

        guard let nextInput = makeVideoInput(position: nextPosition), captureSession.canAddInput(nextInput) else {
            restorePreviousInput()
            return nil
        }

        captureSession.addInput(nextInput)
        videoInput = nextInput
        cameraPosition = nextPosition
        updateRotationCoordinator(for: nextInput.device)
        return nextPosition
    }

    func capturePhoto(flashMode requestedFlashMode: CameraFlashMode) async -> Data? {
        guard photoCaptureDelegate == nil else { return nil }

        let settings = makePhotoSettings(flashMode: requestedFlashMode)
        return await withCheckedContinuation { continuation in
            let delegate = CameraPhotoCaptureDelegate { [weak self] photoData in
                continuation.resume(returning: photoData)
                Task { await self?.clearPhotoCaptureDelegate() }
            }
            photoCaptureDelegate = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func acceptsRequest(_ generation: Int) -> Bool {
        guard generation >= latestGeneration else { return false }
        latestGeneration = generation
        return true
    }

    private func makePhotoSettings(flashMode requestedFlashMode: CameraFlashMode) -> AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(requestedFlashMode.avFoundationMode) {
            settings.flashMode = requestedFlashMode.avFoundationMode
        }
        return settings
    }

    private func restorePreviousInput() {
        guard let videoInput, captureSession.canAddInput(videoInput) else { return }
        captureSession.addInput(videoInput)
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
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position.avFoundationPosition
        ) else { return nil }
        return try? AVCaptureDeviceInput(device: device)
    }

    private func updateRotationCoordinator(for device: AVCaptureDevice) {
        let previewLayer = captureSession.connections.compactMap(\.videoPreviewLayer).first
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        rotationObservers.removeAll()

        updatePreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
        updateCaptureRotation(coordinator.videoRotationAngleForHorizonLevelCapture)

        rotationObservers = [
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { [weak self] _, change in
                guard let self, let rotationAngle = change.newValue else { return }
                Task { await self.updatePreviewRotation(rotationAngle) }
            },
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: .new) { [weak self] _, change in
                guard let self, let rotationAngle = change.newValue else { return }
                Task { await self.updateCaptureRotation(rotationAngle) }
            }
        ]
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
