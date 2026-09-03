//
//  ToppingCandidateSelectionView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/22/26.
//

import SwiftUI
import UIComponent

struct ToppingCandidateSelectionView: View {
    let photo: NormalizedPhoto
    let candidates: [ExtractionCandidate]
    let onBackTap: () -> Void
    let onCandidateTap: (CGPoint) -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var displayImage: CGImage?
    @State private var imageAreaSize: CGSize = .zero

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
                .overlay(alignment: .top) {
                    guideBanner
                }
                .padding(.horizontal, .padding7)
                .padding(.vertical, .padding6)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            backBar
        }
        // 분석용 원본은 화면보다 훨씬 커서 그대로 그리면 그 크기의 백킹 스토어를 잡는다.
        .task(id: displayLongEdge) {
            guard displayLongEdge > 0 else { return }
            let sourceImage = photo.image
            let longEdge = displayLongEdge
            displayImage = await Task.detached(priority: .userInitiated) {
                sourceImage.downscaled(longEdge: longEdge)
            }.value
        }
    }

    /// 표시에 필요한 픽셀 크기. 레이아웃이 미세하게 흔들려도 같은 값으로 수렴하도록 64 단위로 올림한다.
    private var displayLongEdge: CGFloat {
        let targetLongEdge = max(imageAreaSize.width, imageAreaSize.height) * displayScale
        guard targetLongEdge > 0 else { return 0 }
        return (targetLongEdge / 64).rounded(.up) * 64
    }

    private var backBar: some View {
        HStack(spacing: 0) {
            YGCircleButton(.icCaretLeft, variant: .default, action: onBackTap)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, .padding7)
        .padding(.top, .padding6)
    }

    private var guideBanner: some View {
        HStack(spacing: .gap2) {
            Image.icWarningRound
                .renderingMode(.template)
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundStyle(.soda500)

            Text("토핑으로 사용할 대상을 하나 선택해 주세요")
                .suit(.body02Regular)
                .foregroundStyle(.whiteFixed)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, .padding5)
        .padding(.vertical, .padding3)
        .background(.black75)
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
            .fill(.black75)
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
