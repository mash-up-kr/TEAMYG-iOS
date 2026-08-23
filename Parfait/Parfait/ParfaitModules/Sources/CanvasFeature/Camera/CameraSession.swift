//
//  CameraSession.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import AVFoundation
import Foundation

actor CameraSession {
    let previewSource: any CameraPreviewSource

    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let previewFrameReceiver = CameraPreviewFrameReceiver()
    private let previewFrameQueue = DispatchQueue(label: "com.parfait.camera.preview-frame")
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
        guard acceptsRequest(generation) else { return }
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        previewFrameReceiver.pauseAndClear()
        cancelPendingPhotoCapture()
    }

    func switchCamera() -> CameraPosition? {
        guard isConfigured else { return nil }

        let nextPosition = cameraPosition.flipped
        previewFrameReceiver.pauseAndClear()
        captureSession.beginConfiguration()

        if let videoInput {
            captureSession.removeInput(videoInput)
        }

        guard let nextInput = makeVideoInput(position: nextPosition), captureSession.canAddInput(nextInput) else {
            restorePreviousInput()
            captureSession.commitConfiguration()
            if let device = videoInput?.device {
                updateRotationCoordinator(for: device)
            }
            return nil
        }

        captureSession.addInput(nextInput)
        applyMaxPhotoDimensions(for: nextInput.device)
        videoInput = nextInput
        cameraPosition = nextPosition
        captureSession.commitConfiguration()
        updateRotationCoordinator(for: nextInput.device)
        return nextPosition
    }

    func latestPreviewFrame() -> CameraPreviewFrame? {
        previewFrameReceiver.latestFrame()
    }

    func capturePhoto(flashMode requestedFlashMode: CameraFlashMode) async -> Data? {
        guard photoCaptureDelegate == nil else { return nil }

        let settings = makePhotoSettings(flashMode: requestedFlashMode)
        let captureDelegate = CameraPhotoCaptureDelegate()
        photoCaptureDelegate = captureDelegate

        let photoData = await withCheckedContinuation { continuation in
            captureDelegate.setCompletion { continuation.resume(returning: $0) }
            photoOutput.capturePhoto(with: settings, delegate: captureDelegate)
        }

        if photoCaptureDelegate === captureDelegate {
            photoCaptureDelegate = nil
        }
        return photoData
    }

    private func acceptsRequest(_ generation: Int) -> Bool {
        guard generation >= latestGeneration else { return false }
        latestGeneration = generation
        return true
    }

    private func makePhotoSettings(flashMode requestedFlashMode: CameraFlashMode) -> AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings()
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        settings.photoQualityPrioritization = .speed
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
              captureSession.canAddOutput(photoOutput),
              captureSession.canAddOutput(videoDataOutput) else { return false }

        configureVideoDataOutput()
        captureSession.addInput(input)
        captureSession.addOutput(photoOutput)
        captureSession.addOutput(videoDataOutput)
        applyMaxPhotoDimensions(for: input.device)
        videoInput = input
        isConfigured = true
        return true
    }

    private func applyMaxPhotoDimensions(for device: AVCaptureDevice) {
        let largestDimensions = device.activeFormat.supportedMaxPhotoDimensions.max {
            Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
        }
        guard let largestDimensions else { return }
        photoOutput.maxPhotoDimensions = largestDimensions
    }

    private func makeVideoInput(position: CameraPosition) -> AVCaptureDeviceInput? {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position.avFoundationPosition
        ) else { return nil }
        return try? AVCaptureDeviceInput(device: device)
    }

    private func configureVideoDataOutput() {
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoDataOutput.setSampleBufferDelegate(previewFrameReceiver, queue: previewFrameQueue)
    }

    private func updateRotationCoordinator(for device: AVCaptureDevice) {
        let previewLayer = captureSession.connections.compactMap(\.videoPreviewLayer).first
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        rotationObservers.removeAll()

        applyRotationAngle(coordinator.videoRotationAngleForHorizonLevelPreview)

        rotationObservers = [
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { [weak self] _, change in
                guard let self, let rotationAngle = change.newValue else { return }
                Task { await self.applyRotationAngle(rotationAngle) }
            }
        ]
    }

    private func applyRotationAngle(_ rotationAngle: CGFloat) {
        updatePreviewRotation(rotationAngle)
        updateCaptureRotation(rotationAngle)
    }

    private func updatePreviewRotation(_ rotationAngle: CGFloat) {
        let previewSource = previewSource
        Task { @MainActor in
            previewSource.applyPreviewRotationAngle(rotationAngle)
        }
    }

    private func updateCaptureRotation(_ rotationAngle: CGFloat) {
        previewFrameReceiver.pauseAndClear()
        defer { previewFrameReceiver.resume() }

        guard let photoConnection = photoOutput.connection(with: .video) else { return }
        if photoConnection.isVideoRotationAngleSupported(rotationAngle) {
            photoConnection.videoRotationAngle = rotationAngle
        }

        if let videoConnection = videoDataOutput.connection(with: .video) {
            if videoConnection.isVideoRotationAngleSupported(rotationAngle) {
                videoConnection.videoRotationAngle = rotationAngle
            }
            if videoConnection.isVideoMirroringSupported {
                videoConnection.automaticallyAdjustsVideoMirroring = false
                videoConnection.isVideoMirrored = photoConnection.isVideoMirrored
            }
        }
    }

    private func cancelPendingPhotoCapture() {
        guard let pendingDelegate = photoCaptureDelegate else { return }
        photoCaptureDelegate = nil
        pendingDelegate.cancel()
    }
}
