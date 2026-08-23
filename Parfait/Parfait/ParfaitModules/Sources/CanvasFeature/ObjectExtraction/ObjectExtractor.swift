//
//  ObjectExtractor.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/22/26.
//

import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import ImageIO
import Photos
import Vision

protocol ObjectExtracting: Sendable {
    func analyze(_ source: PhotoAnalysisSource) async throws -> PhotoAnalysis
    func extractTopping(candidateID: Int) async throws -> ExtractedTopping
    /// 분석 세션(원본 이미지·Vision 핸들러·마스크 관측)을 놓아준다. 누끼 흐름을 벗어날 때 호출한다.
    func reset() async
}

actor ObjectExtractor: ObjectExtracting {
    private let renderContext = CIContext(options: [.cacheIntermediates: false])
    private var session: AnalysisSession?

    func analyze(_ source: PhotoAnalysisSource) async throws -> PhotoAnalysis {
        session = nil
        return try await withAnalysisTimeout { [self] in
            try await performAnalysis(source)
        }
    }

    func extractTopping(candidateID: Int) throws -> ExtractedTopping {
        guard let session else { throw ObjectExtractionError.analysisFailed }
        guard let candidate = session.candidates.first(where: { $0.id == candidateID }) else {
            throw ObjectExtractionError.candidateNotFound
        }

        let pixelSize = session.photo.pixelSize
        let canvasRect = extractionCanvasRect(of: candidate.pixelBoundingBox(in: pixelSize))
        let cutoutRect = canvasRect
            .intersection(CGRect(origin: .zero, size: pixelSize))
            .integral
        guard canvasRect.width > 0, canvasRect.height > 0,
              cutoutRect.width >= 1, cutoutRect.height >= 1
        else { throw ObjectExtractionError.renderingFailed }

        let maskBuffer: CVPixelBuffer
        do {
            maskBuffer = try session.observation.generateScaledMask(
                for: IndexSet(integer: candidateID),
                scaledToImageFrom: session.requestHandler
            )
        } catch {
            throw ObjectExtractionError.renderingFailed
        }

        let cutout = try renderCutout(of: session.photo.image, maskBuffer: maskBuffer, in: cutoutRect)
        let extractionCanvas = try renderExtractionCanvas(
            cutout: cutout,
            cutoutRect: cutoutRect,
            canvasRect: canvasRect
        )
        return ExtractedTopping(candidateID: candidateID, image: extractionCanvas)
    }

    func reset() {
        session = nil
    }

    private func performAnalysis(_ source: PhotoAnalysisSource) async throws -> PhotoAnalysis {
        let photo = try await normalizedPhoto(from: source)
        try Task.checkCancellation()

        // `NormalizedPhoto` 는 이미 분석 해상도 이하로 맞춰져 있다.
        let requestHandler = ImageRequestHandler(photo.image)

        let observation: InstanceMaskObservation?
        do {
            observation = try await requestHandler.perform(GenerateForegroundInstanceMaskRequest())
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ObjectExtractionError.analysisFailed
        }
        guard let observation else { throw ObjectExtractionError.noCandidates }

        let candidates = try makeCandidates(from: observation)
        guard !candidates.isEmpty else { throw ObjectExtractionError.noCandidates }
        try Task.checkCancellation()

        session = AnalysisSession(
            photo: photo,
            requestHandler: requestHandler,
            observation: observation,
            candidates: candidates
        )
        return PhotoAnalysis(photo: photo, candidates: candidates)
    }

    private func makeCandidates(from observation: InstanceMaskObservation) throws -> [ExtractionCandidate] {
        var candidates: [ExtractionCandidate] = []

        for instance in observation.allInstances {
            try Task.checkCancellation()
            // 인스턴스마다 분석 해상도 크기의 마스크 버퍼가 뜬다 — 다음 인스턴스로 넘어가기 전에 회수한다.
            let candidate = autoreleasepool { () -> ExtractionCandidate? in
                guard let maskBuffer = try? observation.generateMask(for: IndexSet(integer: instance)),
                      let metrics = InstanceMaskScanner.metrics(of: maskBuffer),
                      metrics.areaRatio >= ObjectExtractionPolicy.minimumCandidateAreaRatio
                else { return nil }

                return ExtractionCandidate(
                    id: instance,
                    normalizedBoundingBox: metrics.normalizedBoundingBox,
                    areaRatio: metrics.areaRatio
                )
            }
            if let candidate {
                candidates.append(candidate)
            }
        }

        return Array(
            candidates
                .sorted { $0.areaRatio > $1.areaRatio }
                .prefix(ObjectExtractionPolicy.maximumCandidateCount)
        )
    }

    private func renderCutout(
        of sourceImage: CGImage,
        maskBuffer: CVPixelBuffer,
        in cutoutRect: CGRect
    ) throws -> CGImage {
        let source = CIImage(cgImage: sourceImage)
        let mask = CIImage(cvPixelBuffer: maskBuffer)
        guard mask.extent.width > 0, mask.extent.height > 0 else {
            throw ObjectExtractionError.renderingFailed
        }

        let scaledMask = mask.transformed(
            by: CGAffineTransform(
                scaleX: source.extent.width / mask.extent.width,
                y: source.extent.height / mask.extent.height
            )
        )
        let cutoutImage = source.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: CIImage.empty(),
                kCIInputMaskImageKey: scaledMask
            ]
        )

        // Core Image 는 요청한 영역만 렌더한다 — 원본 전체 크기 RGBA 비트맵을 만들지 않도록 잘라낼 영역만 넘긴다.
        // `cutoutRect` 는 좌상단 원점, CIImage 는 좌하단 원점이라 y 를 뒤집어 맞춘다.
        let renderRect = CGRect(
            x: cutoutRect.minX,
            y: source.extent.height - cutoutRect.maxY,
            width: cutoutRect.width,
            height: cutoutRect.height
        )
        guard let cutout = renderContext.createCGImage(cutoutImage, from: renderRect) else {
            throw ObjectExtractionError.renderingFailed
        }
        return cutout
    }

    /// 후보를 감싸는 여백 포함 영역. 사진 밖으로 나가는 부분은 결과물에서 투명 여백이 된다.
    private func extractionCanvasRect(of boundingBox: CGRect) -> CGRect {
        let margin = max(
            min(boundingBox.width, boundingBox.height) * ObjectExtractionPolicy.safeMarginRatio,
            ObjectExtractionPolicy.minimumSafeMargin
        )
        return boundingBox.insetBy(dx: -margin, dy: -margin)
    }

    private func renderExtractionCanvas(
        cutout: CGImage,
        cutoutRect: CGRect,
        canvasRect: CGRect
    ) throws -> CGImage {
        let scale = min(
            1,
            ObjectExtractionPolicy.extractionCanvasLongEdge / max(canvasRect.width, canvasRect.height)
        )
        let canvasWidth = max(1, Int((canvasRect.width * scale).rounded()))
        let canvasHeight = max(1, Int((canvasRect.height * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ObjectExtractionError.renderingFailed
        }

        context.interpolationQuality = .high
        context.draw(
            cutout,
            in: CGRect(
                x: (cutoutRect.minX - canvasRect.minX) * scale,
                y: (canvasRect.maxY - cutoutRect.maxY) * scale,
                width: cutoutRect.width * scale,
                height: cutoutRect.height * scale
            )
        )

        guard let canvasImage = context.makeImage() else {
            throw ObjectExtractionError.renderingFailed
        }
        return canvasImage
    }

    private struct AnalysisSession {
        let photo: NormalizedPhoto
        let requestHandler: ImageRequestHandler
        let observation: InstanceMaskObservation
        let candidates: [ExtractionCandidate]
    }
}

/// 분석에 넣을 사진을 준비하는 단계 — 원본 로드·방향 보정·분석 해상도 축소.
private extension ObjectExtractor {
    /// 분석에 쓸 사진 — 항상 정방향이고 긴 변이 `analysisLongEdge` 이하다.
    private func normalizedPhoto(from source: PhotoAnalysisSource) async throws -> NormalizedPhoto {
        switch source {
        case .cameraPhoto(let photoData, let viewFinderRegion):
            // 뷰파인더로 잘라낸 뒤에도 분석 해상도가 남도록, 잘려나갈 비율만큼 여유를 두고 디코딩한다.
            let coverageRatio = viewFinderRegion?.previewCoverageRatio ?? 1
            let photo = try uprightPhoto(
                from: photoData,
                orientation: nil,
                longEdge: min(
                    ObjectExtractionPolicy.analysisLongEdge / coverageRatio,
                    ObjectExtractionPolicy.maximumDecodeLongEdge
                )
            )
            let croppedPhoto = cropped(photo, to: viewFinderRegion)
            // 크롭은 원본 비트맵을 공유하므로, 여기서 축소본을 떠야 큰 비트맵이 풀린다.
            return NormalizedPhoto(
                image: croppedPhoto.image.downscaled(longEdge: ObjectExtractionPolicy.analysisLongEdge)
            )
        case .galleryAsset(let identifier):
            guard let original = await galleryOriginal(assetIdentifier: identifier) else {
                throw ObjectExtractionError.photoUnavailable
            }
            return try uprightPhoto(
                from: original.photoData,
                orientation: original.orientation,
                longEdge: ObjectExtractionPolicy.analysisLongEdge
            )
        }
    }

    /// 원본을 통째로 디코딩하지 않고 `longEdge` 로 축소하며 디코딩한다.
    /// 최종 결과물은 `extractionCanvasLongEdge` 이하라 원본 해상도를 들고 있어도 화질 이득이 없다.
    private func uprightPhoto(
        from photoData: Data,
        orientation explicitOrientation: CGImagePropertyOrientation?,
        longEdge: CGFloat
    ) throws -> NormalizedPhoto {
        // 명시 방향(앨범 원본)이 있으면 그 값을 직접 적용하고, 없으면(카메라 촬영) 파일에 기록된 방향을 디코딩 단계에서 적용한다.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: explicitOrientation == nil,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(longEdge.rounded()))
        ]
        guard let imageSource = CGImageSourceCreateWithData(photoData as CFData, nil),
              let decodedImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        else {
            throw ObjectExtractionError.photoUnavailable
        }

        guard let explicitOrientation, explicitOrientation != .up else {
            return NormalizedPhoto(image: decodedImage)
        }

        let orientedImage = CIImage(cgImage: decodedImage).oriented(explicitOrientation)
        guard let uprightImage = renderContext.createCGImage(orientedImage, from: orientedImage.extent) else {
            throw ObjectExtractionError.photoUnavailable
        }
        return NormalizedPhoto(image: uprightImage)
    }

    private func cropped(_ photo: NormalizedPhoto, to viewFinderRegion: ViewFinderRegion?) -> NormalizedPhoto {
        guard let viewFinderRegion,
              let croppedImage = viewFinderRegion.croppedImage(from: photo.image)
        else { return photo }
        return NormalizedPhoto(image: croppedImage)
    }

    private func galleryOriginal(
        assetIdentifier: String
    ) async -> (photoData: Data, orientation: CGImagePropertyOrientation)? {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier],
            options: nil
        ).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { photoData, _, orientation, _ in
                guard let photoData else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (photoData, orientation))
            }
        }
    }
}

private func withAnalysisTimeout<Value: Sendable>(
    _ duration: Duration = ObjectExtractionPolicy.analysisTimeout,
    operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: duration)
            throw ObjectExtractionError.timedOut
        }
        defer { group.cancelAll() }

        guard let value = try await group.next() else {
            throw ObjectExtractionError.analysisFailed
        }
        return value
    }
}
