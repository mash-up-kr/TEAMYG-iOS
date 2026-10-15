//
//  ToppingCandidateSelectionView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/22/26.
//

import Common
import SwiftUI
import UIComponent

struct ToppingCandidateSelectionView: View {
    let photo: NormalizedPhoto
    let candidates: [ExtractionCandidate]
    let onBackTap: () -> Void
    let onCloseTap: () -> Void
    let onCandidateTap: (CGPoint) -> Void
    let onManualSelectionTap: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var displayImage: CGImage?
    @State private var imageAreaSize: CGSize = .zero
    @State private var isGuideAlertPresented = false

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            Image(decorative: displayImage ?? photo.image, scale: 1, orientation: .up)
                .resizable()
                .scaledToFit()
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { newSize in
                    imageAreaSize = newSize
                }
                .overlay { candidateOverlay }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // 이미지 영역 상단 경계에서 내려온다 (기존 안내 배너 자리).
                .ygAlert(isPresented: $isGuideAlertPresented) {
                    YGAlert(
                        title: "대상을 직접 선택할 수 있어요",
                        subtitle: "원하는 대상이 없다면 직접 편집해요",
                        action: .init("직접 선택", handler: onManualSelectionTap)
                    )
                }
                .padding(.horizontal, .padding7)
                .padding(.vertical, .padding6)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(.backTitleClose("대상 선택"), onBack: onBackTap, onClose: onCloseTap)
        }
        // 첫 렌더 이후에 켜야 위에서 내려오는 등장 모션이 난다.
        .onAppear { isGuideAlertPresented = true }
        // 분석용 원본은 화면보다 훨씬 커서 그대로 그리면 그 크기의 백킹 스토어를 잡는다.
        .task(id: displayLongEdge) {
            guard displayLongEdge > 0 else { return }
            do {
                let downscaledImage = try await Self.downscaledDisplayImage(
                    from: photo.image,
                    longEdge: displayLongEdge
                )
                guard !Task.isCancelled else { return }
                displayImage = downscaledImage
            } catch {
                return
            }
        }
    }

    /// 표시에 필요한 픽셀 크기. 레이아웃이 미세하게 흔들려도 같은 값으로 수렴하도록 64 단위로 올림한다.
    private var displayLongEdge: CGFloat {
        let targetLongEdge = max(imageAreaSize.width, imageAreaSize.height) * displayScale
        guard targetLongEdge > 0 else { return 0 }
        return (targetLongEdge / 64).rounded(.up) * 64
    }

    @concurrent
    private static func downscaledDisplayImage(from image: CGImage, longEdge: CGFloat) async throws -> CGImage {
        try Task.checkCancellation()
        let downscaledImage = image.downscaled(longEdge: longEdge)
        try Task.checkCancellation()
        return downscaledImage
    }

    private var candidateOverlay: some View {
        GeometryReader { proxy in
            let imageSize = proxy.size

            ZStack {
                backgroundDim(in: imageSize)

                ForEach(candidates) { candidate in
                    let boundingBox = rect(of: candidate, in: imageSize)

                    Rectangle()
                        .stroke(.whiteFixed, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .frame(width: boundingBox.width, height: boundingBox.height)
                        .position(x: boundingBox.midX, y: boundingBox.midY)
                }
            }
            .contentShape(.rect)
            .gesture(
                SpatialTapGesture()
                    .onEnded { tap in
                        guard imageSize.width > 0, imageSize.height > 0 else { return }
                        onCandidateTap(
                            CGPoint(
                                x: tap.location.x / imageSize.width,
                                y: tap.location.y / imageSize.height
                            )
                        )
                    }
            )
        }
    }

    private func backgroundDim(in imageSize: CGSize) -> some View {
        let imageRect = CGRect(origin: .zero, size: imageSize)
        let candidateShape = candidates.reduce(into: Path()) { shape, candidate in
            shape.addPath(Path(rect(of: candidate, in: imageSize)))
        }

        return Path(imageRect)
            .subtracting(candidateShape)
            .fill(.black25)
    }

    private func rect(of candidate: ExtractionCandidate, in imageSize: CGSize) -> CGRect {
        CGRect(
            x: candidate.normalizedBoundingBox.minX * imageSize.width,
            y: candidate.normalizedBoundingBox.minY * imageSize.height,
            width: candidate.normalizedBoundingBox.width * imageSize.width,
            height: candidate.normalizedBoundingBox.height * imageSize.height
        )
    }
}
