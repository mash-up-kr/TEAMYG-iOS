//
//  ToppingAddStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import CoreGraphics
import Foundation
import Observation
import UIKit
import UIComponent

@Observable @MainActor
final class ToppingAddStore: MVIStore {
    private(set) var state: State

    private let cameraSession = CameraSession()
    private let objectExtractor: any ObjectExtracting
    private var cameraSetupTask: Task<Void, Never>?
    private var cameraSwitchTask: Task<Void, Never>?
    private var photoCaptureTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var extractorResetTask: Task<Void, Never>?
    /// 켜기/끄기 요청에 붙이는 일련번호. 발급은 순서가 보장되는 MainActor 에서만 한다.
    private var cameraGeneration = 0

    init(
        canvasDate: CalendarDate,
        photoSource: PhotoSource,
        objectExtractor: any ObjectExtracting = ObjectExtractor()
    ) {
        state = State(canvasDate: canvasDate, photoSource: photoSource)
        self.objectExtractor = objectExtractor
    }

    var previewSource: any CameraPreviewSource {
        cameraSession.previewSource
    }

    func send(_ intent: Intent) {
        switch intent {
        case .settingsTapped:
            openSystemSettings()

        case .toastDismissed:
            state.showsToast = false

        case .screenAppeared, .screenDisappeared, .sceneBecameActive, .sceneEnteredBackground,
             .cameraRetryTapped, .flashTapped, .cameraPositionTapped, .shutterTapped, .retakeTapped:
            handleCameraIntent(intent)

        case .photoConfirmed, .galleryPhotoConfirmed, .analysisCancelled, .candidateTapped,
             .candidateSelectionBackTapped, .analysisErrorClosed, .cutoutResultClosed,
             .photoEditTapped, .cutoutConfirmed:
            handleAnalysisIntent(intent)
        }
    }

    private func handleCameraIntent(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .sceneBecameActive:
            resumeCameraIfNeeded()
        case .screenDisappeared:
            cancelAnalysis()
            suspendCamera()
        case .sceneEnteredBackground:
            suspendCamera()
        case .cameraRetryTapped:
            prepareCamera()
        case .flashTapped:
            state.flashMode = state.flashMode.toggled
        case .cameraPositionTapped:
            switchCamera()
        case .shutterTapped(let viewFinderRegion):
            capturePhoto(viewFinderRegion: viewFinderRegion)
        case .retakeTapped:
            retakePhoto()
        default:
            break
        }
    }

    private func handleAnalysisIntent(_ intent: Intent) {
        switch intent {
        case .photoConfirmed:
            proceedWithCapturedPhoto()
        case .galleryPhotoConfirmed(let assetIdentifier):
            confirmGalleryPhoto(assetIdentifier: assetIdentifier)
        case .analysisCancelled:
            cancelAnalysis()
        case .candidateTapped(let normalizedPoint):
            extractCandidate(at: normalizedPoint)
        case .candidateSelectionBackTapped, .analysisErrorClosed:
            returnToPhotoConfirm()
        case .cutoutResultClosed:
            state.extractedTopping = nil
            state.screen = .candidateSelection
        case .photoEditTapped, .cutoutConfirmed:
            break
        default:
            break
        }
    }

    private func proceedWithCapturedPhoto() {
        switch state.photoCapturePhase {
        case .processing:
            state.screen = .analysisLoading
        case .ready(_, let photoData):
            startAnalysis(of: .cameraPhoto(photoData, viewFinderRegion: state.capturedViewFinderRegion))
        case .idle:
            break
        }
    }

    private func confirmGalleryPhoto(assetIdentifier: String) {
        state.galleryAssetIdentifier = assetIdentifier
        startAnalysis(of: .galleryAsset(identifier: assetIdentifier))
    }

    private func startAnalysis(of source: PhotoAnalysisSource) {
        analysisTask?.cancel()
        state.analysis = nil
        state.extractedTopping = nil
        state.screen = .analysisLoading

        analysisTask = Task { [weak self, objectExtractor, extractorResetTask] in
            do {
                await extractorResetTask?.value
                try Task.checkCancellation()
                let analysis = try await objectExtractor.analyze(source)
                guard let self, !Task.isCancelled else { return }
                state.analysis = analysis
                state.screen = .candidateSelection
                releaseCapturedPreviewFrame()
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                state.screen = .analysisError
            }
        }
    }

    private func extractCandidate(at normalizedPoint: CGPoint) {
        guard state.screen == .candidateSelection,
              let candidate = state.analysis?.candidate(at: normalizedPoint)
        else { return }

        analysisTask?.cancel()
        state.extractedTopping = nil
        state.screen = .analysisLoading

        analysisTask = Task { [weak self, objectExtractor] in
            do {
                let topping = try await objectExtractor.extractTopping(candidateID: candidate.id)
                guard let self, !Task.isCancelled else { return }
                state.extractedTopping = topping
                state.screen = .cutoutResult
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                state.screen = .analysisError
            }
        }
    }

    private func returnToPhotoConfirm() {
        cancelAnalysis()
        state.screen = state.photoSource.confirmScreen
    }

    private func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        state.analysis = nil
        state.extractedTopping = nil
        extractorResetTask = Task { [objectExtractor] in
            await objectExtractor.reset()
        }
    }

    private func resumeCameraIfNeeded() {
        guard state.screen.needsRunningCamera else { return }
        prepareCamera()
    }

    private func prepareCamera() {
        cameraSetupTask?.cancel()
        let generation = nextCameraGeneration()
        state.cameraPhase = .preparing

        cameraSetupTask = Task { [weak self] in
            guard let self, await resolveAuthorization() else { return }
            await startCamera(generation: generation)
        }
    }

    private func resolveAuthorization() async -> Bool {
        let isAuthorized = switch CameraPermission.current() {
        case .authorized: true
        case .notDetermined: await CameraPermission.request()
        case .denied, .restricted: false
        }

        guard !Task.isCancelled else { return false }
        guard isAuthorized else {
            state.cameraPhase = .permissionDenied
            state.screen = .cameraPermissionError
            return false
        }
        return true
    }

    private func startCamera(generation: Int) async {
        let didStart = await cameraSession.start(generation: generation)
        guard isLatestRequest(generation) else { return }

        if didStart {
            state.cameraPhase = .running
            if state.screen.isCameraError {
                state.screen = .camera
            }
        } else {
            state.cameraPhase = .unavailable
            state.screen = .cameraUnavailable
        }
    }

    private func suspendCamera() {
        cancelCameraTasks()
        if case .processing = state.photoCapturePhase {
            state.photoCapturePhase = .idle
            state.capturedViewFinderRegion = nil
            state.screen = .camera
        }
        let generation = nextCameraGeneration()
        state.cameraPhase = .idle
        Task { [cameraSession] in
            await cameraSession.stop(generation: generation)
        }
    }

    private func switchCamera() {
        guard state.isCameraReady else { return }
        state.isSwitchingCamera = true
        cameraSwitchTask = Task { [weak self, cameraSession] in
            let switchedPosition = await cameraSession.switchCamera()
            guard let self else { return }

            state.isSwitchingCamera = false
            guard let switchedPosition else { return }

            state.cameraPosition = switchedPosition
            if switchedPosition == .front {
                state.flashMode = .off
            }
        }
    }

    private func capturePhoto(viewFinderRegion: ViewFinderRegion?) {
        guard state.isCameraReady else { return }

        let captureGeneration = nextCameraGeneration()
        state.capturedViewFinderRegion = viewFinderRegion
        state.photoCapturePhase = .processing(previewFrame: nil)

        photoCaptureTask = Task { [weak self, cameraSession, flashMode = state.flashMode] in
            async let pendingPhotoData = cameraSession.capturePhoto(flashMode: flashMode)
            let previewFrame = await cameraSession.latestPreviewFrame()

            guard let self, isLatestRequest(captureGeneration) else { return }
            if let previewFrame {
                state.photoCapturePhase = .processing(previewFrame: previewFrame)
                state.screen = .cameraConfirmation
            }

            let photoData = await pendingPhotoData
            guard isLatestRequest(captureGeneration) else { return }

            guard let photoData else {
                state.photoCapturePhase = .idle
                state.screen = .camera
                photoCaptureTask = nil
                prepareCamera()
                return
            }

            let shouldStartAnalysis = state.screen == .analysisLoading
            state.photoCapturePhase = .ready(previewFrame: previewFrame, photoData: photoData)
            photoCaptureTask = nil

            if shouldStartAnalysis {
                startAnalysis(of: .cameraPhoto(photoData, viewFinderRegion: viewFinderRegion))
            } else {
                state.screen = .cameraConfirmation
            }
            await cameraSession.stop(generation: nextCameraGeneration())
        }
    }
}

private extension ToppingAddStore {
    private func releaseCapturedPreviewFrame() {
        guard case .ready(let previewFrame, let photoData) = state.photoCapturePhase, previewFrame != nil else {
            return
        }
        state.photoCapturePhase = .ready(previewFrame: nil, photoData: photoData)
    }

    private func retakePhoto() {
        guard state.isRetakeEnabled else { return }
        photoCaptureTask?.cancel()
        photoCaptureTask = nil
        state.photoCapturePhase = .idle
        state.capturedViewFinderRegion = nil
        state.screen = .camera
        prepareCamera()
    }

    private func openSystemSettings() {
        Task {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            await UIApplication.shared.open(settingsURL)
        }
    }

    /// 켜기/끄기 요청에 붙일 새 일련번호. 뒤늦게 도착한 옛 요청은 `CameraSession` 이 무시한다.
    private func nextCameraGeneration() -> Int {
        cameraGeneration += 1
        return cameraGeneration
    }

    private func isLatestRequest(_ generation: Int) -> Bool {
        !Task.isCancelled && generation == cameraGeneration
    }

    private func cancelCameraTasks() {
        cameraSetupTask?.cancel()
        cameraSwitchTask?.cancel()
        photoCaptureTask?.cancel()
        cameraSetupTask = nil
        cameraSwitchTask = nil
        photoCaptureTask = nil
        state.isSwitchingCamera = false
    }
}
