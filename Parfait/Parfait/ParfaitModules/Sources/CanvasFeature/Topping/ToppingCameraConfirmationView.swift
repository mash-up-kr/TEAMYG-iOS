//
//  ToppingCameraConfirmationView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import SwiftUI
import UIComponent
import UIKit

struct ToppingCameraConfirmationView: View {
    let previewFrame: CameraPreviewFrame?
    let photoData: Data?
    let viewFinderRegion: ViewFinderRegion?
    let isRetakeEnabled: Bool
    let isNextEnabled: Bool
    let onRetakeTap: () -> Void
    let onNextTap: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var capturedImage: UIImage?
    @State private var previewImage: CGImage?
    @State private var imageAreaSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: 0) {
                capturedImageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { newSize in
                        imageAreaSize = newSize
                    }

                HStack(spacing: .gap4) {
                    YGButton("다시 찍기", variant: .mediumSecondary, fillsWidth: true, action: onRetakeTap)
                        .disabled(!isRetakeEnabled)
                    YGButton("다음", variant: .mediumPrimary, fillsWidth: true, action: onNextTap)
                        .disabled(!isNextEnabled)
                }
                .padding(.top, .padding6)
            }
            .padding(.horizontal, .padding7)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(.close)
        }
        .task(id: previewFrame) {
            previewImage = Self.croppedPreviewImage(from: previewFrame, viewFinderRegion: viewFinderRegion)
        }
        .task(id: DisplayRequest(
            photoData: photoData,
            areaSize: imageAreaSize,
            displayScale: displayScale,
            viewFinderRegion: viewFinderRegion
        )) {
            capturedImage = await Self.decodeImage(
                from: photoData,
                areaSize: imageAreaSize,
                displayScale: displayScale,
                viewFinderRegion: viewFinderRegion
            )
        }
    }

    @ViewBuilder
    private var capturedImageView: some View {
        if let capturedImage {
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFit()
        } else if let previewImage {
            Image(decorative: previewImage, scale: 1)
                .resizable()
                .scaledToFit()
        } else {
            Color.gray100
        }
    }

    private static func croppedPreviewImage(
        from previewFrame: CameraPreviewFrame?,
        viewFinderRegion: ViewFinderRegion?
    ) -> CGImage? {
        guard let previewFrame else { return nil }
        guard let viewFinderRegion else { return previewFrame.image }
        return viewFinderRegion.croppedImage(from: previewFrame.image) ?? previewFrame.image
    }

    private static func decodeImage(
        from photoData: Data?,
        areaSize: CGSize,
        displayScale: CGFloat,
        viewFinderRegion: ViewFinderRegion?
    ) async -> UIImage? {
        guard let photoData, areaSize != .zero else { return nil }

        let coverageRatio = viewFinderRegion?.previewCoverageRatio ?? 1
        let maxPixelSize = Int((max(areaSize.width, areaSize.height) * displayScale / coverageRatio).rounded(.up))
        return await Task.detached(priority: .userInitiated) {
            guard let downsampledImage = ImageDownsampling.decodedImage(
                from: photoData,
                maxPixelSize: maxPixelSize
            ) else { return nil }

            guard let viewFinderRegion,
                  let croppedImage = viewFinderRegion.croppedImage(from: downsampledImage)
            else { return UIImage(cgImage: downsampledImage) }

            return UIImage(cgImage: croppedImage)
        }.value
    }

    private struct DisplayRequest: Equatable {
        let photoData: Data?
        let areaSize: CGSize
        let displayScale: CGFloat
        let viewFinderRegion: ViewFinderRegion?
    }
}
