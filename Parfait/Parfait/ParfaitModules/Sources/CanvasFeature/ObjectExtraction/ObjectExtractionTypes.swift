//
//  ObjectExtractionTypes.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/22/26.
//

import CoreGraphics
import Foundation

struct NormalizedPhoto: Equatable, Sendable {
    let image: CGImage

    var pixelSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.image === rhs.image
    }
}

enum PhotoAnalysisSource: Equatable, Sendable {
    case cameraPhoto(Data, viewFinderRegion: ViewFinderRegion?)
    case galleryAsset(identifier: String)
}

struct ExtractionCandidate: Identifiable, Equatable, Sendable {
    let id: Int
    let normalizedBoundingBox: CGRect
    let areaRatio: Double

    func pixelBoundingBox(in pixelSize: CGSize) -> CGRect {
        CGRect(
            x: normalizedBoundingBox.minX * pixelSize.width,
            y: normalizedBoundingBox.minY * pixelSize.height,
            width: normalizedBoundingBox.width * pixelSize.width,
            height: normalizedBoundingBox.height * pixelSize.height
        )
    }
}

struct PhotoAnalysis: Equatable, Sendable {
    let photo: NormalizedPhoto
    let candidates: [ExtractionCandidate]

    func candidate(at normalizedPoint: CGPoint) -> ExtractionCandidate? {
        candidates
            .filter { $0.normalizedBoundingBox.contains(normalizedPoint) }
            .min { $0.normalizedBoundingBox.area < $1.normalizedBoundingBox.area }
    }
}

/// 추출 캔버스 한 벌. `photo`·`mask`·`image` 는 모두 같은 크기이며,
/// `image` 는 `photo` 를 `mask` 로 오려낸 결과다. C-104 는 `photo` 를 배경 가이드로 깔고 `mask` 를 고쳐 쓴다.
struct ExtractedTopping: Equatable, Sendable {
    let candidateID: Int
    let image: CGImage
    let photo: CGImage
    let mask: CGImage

    var pixelSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    func replacingCutout(image: CGImage, mask: CGImage) -> Self {
        Self(candidateID: candidateID, image: image, photo: photo, mask: mask)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.candidateID == rhs.candidateID && lhs.image === rhs.image
    }
}

enum ObjectExtractionError: Error, Equatable, Sendable {
    case photoUnavailable
    case analysisFailed
    case noCandidates
    case candidateNotFound
    case renderingFailed
    case timedOut
}

enum ObjectExtractionPolicy {
    static let analysisLongEdge: CGFloat = 2048
    static let maximumDecodeLongEdge: CGFloat = 4096
    static let minimumCandidateAreaRatio: Double = 0.001
    static let maximumCandidateCount = 10
    static let safeMarginRatio: CGFloat = 0.2
    static let minimumSafeMargin: CGFloat = 50
    static let extractionCanvasLongEdge: CGFloat = 1500
    static let analysisTimeout: Duration = .seconds(30)
}

private extension CGRect {
    var area: CGFloat { width * height }
}
