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
    /// 촬영에는 쓰지 않는다 — 회전·미러링 기준 커넥션으로만 둔다. 사진은 셔터 순간의 프레임을 그대로 쓴다.
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let previewFrameReceiver = CameraPreviewFrameReceiver()
    private let previewFrameQueue = DispatchQueue(label: "com.parfait.camera.preview-frame")
    private var videoInput: AVCaptureDeviceInput?
    private var cameraPosition: CameraPosition = .back
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservers: [NSKeyValueObservation] = []
    private var isConfigured = false
    private var flashMode: CameraFlashMode = .off
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

        previewFrameReceiver.resume()
        if let device = videoInput?.device {
            updateRotationCoordinator(for: device)
        }
        applyTorch(flashMode)
        return true
    }

    func stop(generation: Int) {
        guard acceptsRequest(generation) else { return }
        applyTorch(.off)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        previewFrameReceiver.pauseAndClear()
    }

    func setFlashMode(_ requestedFlashMode: CameraFlashMode) {
        flashMode = requestedFlashMode
        applyTorch(requestedFlashMode)
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
        videoInput = nextInput
        cameraPosition = nextPosition
        captureSession.commitConfiguration()
        updateRotationCoordinator(for: nextInput.device)
        if nextPosition == .front {
            flashMode = .off
        }
        applyTorch(flashMode)
        return nextPosition
    }

    /// 장치가 허용하는 범위로 잘라 적용한다. 미리보기·저장 프레임이 함께 확대된다.
    func setZoomFactor(_ zoomFactor: CGFloat) {
        guard let device = videoInput?.device else { return }
        let range = CameraFlowState.zoomFactorRange
        let minimumZoomFactor = max(device.minAvailableVideoZoomFactor, range.lowerBound)
        let maximumZoomFactor = min(device.maxAvailableVideoZoomFactor, range.upperBound)
        applyZoomFactor(min(max(zoomFactor, minimumZoomFactor), maximumZoomFactor), to: device)
    }

    /// 셔터 순간의 프레임. 사진 출력(AVCapturePhotoOutput)은 요청 뒤 프레임을 찍어 지연이 생기므로 쓰지 않는다.
    func currentFrame() -> CameraPreviewFrame? {
        previewFrameReceiver.latestFrame()
    }

    private func acceptsRequest(_ generation: Int) -> Bool {
        guard generation >= latestGeneration else { return false }
        latestGeneration = generation
        return true
    }

    private func applyTorch(_ requestedFlashMode: CameraFlashMode) {
        let torchMode = requestedFlashMode.avFoundationTorchMode
        guard let device = videoInput?.device, device.hasTorch, device.isTorchModeSupported(torchMode) else {
            return
        }
        do {
            try device.lockForConfiguration()
        } catch {
            return
        }
        device.torchMode = torchMode
        device.unlockForConfiguration()
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
        // 장치 객체는 앱 전역에서 공유돼 이전 화면의 줌이 남아 있다. 상태(1배)와 맞춰 둔다.
        applyZoomFactor(1, to: device)
        return try? AVCaptureDeviceInput(device: device)
    }

    private func applyZoomFactor(_ zoomFactor: CGFloat, to device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
        } catch {
            return
        }
        device.videoZoomFactor = zoomFactor
        device.unlockForConfiguration()
    }

    private func configureVideoDataOutput() {
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        // .photo 프리셋은 기본으로 화면 크기만 한 프리뷰용 버퍼를 준다. 이 프레임이 곧 저장 사진이라 원본 해상도로 받는다.
        // ponytail: 매 프레임이 풀해상도라 메모리·발열 부담이 있다. 문제되면 videoSettings 에 폭·높이를 명시해 낮출 것.
        videoDataOutput.automaticallyConfiguresOutputBufferDimensions = false
        videoDataOutput.deliversPreviewSizedOutputBuffers = false
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
}
