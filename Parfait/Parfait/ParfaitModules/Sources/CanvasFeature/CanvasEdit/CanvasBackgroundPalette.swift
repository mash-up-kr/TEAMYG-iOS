//
//  CanvasBackgroundPalette.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

struct CanvasBackgroundPalette: View {
    private static let colors = [
        "#FAFAFA",
        "#0E0E0E",
        "#FCC2CC",
        "#FCE7C2",
        "#F9F9AB",
        "#C5FFD7",
        "#C2E4FC",
        "#DCC2FC"
    ]

    let background: CanvasStore.CanvasBackground
    let selectedColorHex: String?
    let selectedImageSource: BackgroundImagePickerStore.PhotoSource?
    let onColorSelect: (String) -> Void
    let onImageSourceSelect: (BackgroundImagePickerStore.PhotoSource) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: .gap3) {
                sourceChip(icon: .icGallery, source: .gallery)
                sourceChip(icon: .icCamera, source: .camera)

                ForEach(Self.colors, id: \.self) { hex in
                    colorChip(hex)
                }
            }
            .padding(.vertical, .padding2)
            .padding(.leading, .padding7)
            .padding(.top, .padding6)
        }
        .scrollIndicators(.hidden)
        .frame(height: 60)
        .background(.whiteFixed)
    }

    private func sourceChip(icon: Image, source: BackgroundImagePickerStore.PhotoSource) -> some View {
        Button {
            onImageSourceSelect(source)
        } label: {
            ZStack {
                Circle()
                    .fill(.gray100)

                if selectedImageSource == source {
                    CanvasBackgroundThumbnail(background: background)
                        .clipShape(.circle)
                }

                Circle()
                    .strokeBorder(.black5, lineWidth: 1)

                if selectedImageSource == source {
                    Circle()
                        .fill(.black25)

                    icon
                        .renderingMode(.template)
                        .resizable()
                        .foregroundStyle(.whiteFixed)
                        .frame(width: 24, height: 24)
                } else {
                    icon
                        .renderingMode(.template)
                        .resizable()
                        .foregroundStyle(.gray850)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    private func colorChip(_ hex: String) -> some View {
        Button {
            onColorSelect(hex)
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .overlay {
                    Circle()
                        .strokeBorder(.black5, lineWidth: 1)
                }
                .overlay {
                    if selectedColorHex == hex {
                        Circle()
                            .fill(.black25)
                        Image.icCheck
                            .renderingMode(.template)
                            .resizable()
                            .foregroundStyle(.whiteFixed)
                            .frame(width: 24, height: 24)
                    }
                }
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}

private struct CanvasBackgroundThumbnail: View {
    let background: CanvasStore.CanvasBackground

    var body: some View {
        switch background {
        case .color(let hex):
            Color(hex: hex)

        case .image(let url):
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray100
                }
            }

        case .imageData(let imageData):
            LocalBackgroundThumbnail(imageData: imageData)
        }
    }
}

private struct LocalBackgroundThumbnail: View {
    let imageData: Data

    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray100
                }
            }
            .task(id: DecodeRequest(imageData: imageData, size: proxy.size, displayScale: displayScale)) {
                let maxPixelSize = proxy.size.longEdgePixelSize(scale: displayScale)
                image = await Task.detached(priority: .userInitiated) {
                    ImageDownsampling.decodedImage(from: imageData, maxPixelSize: maxPixelSize)
                }.value
            }
        }
    }

    private struct DecodeRequest: Equatable {
        let imageData: Data
        let size: CGSize
        let displayScale: CGFloat
    }
}
