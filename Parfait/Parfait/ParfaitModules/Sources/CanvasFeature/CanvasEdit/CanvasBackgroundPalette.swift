//
//  CanvasBackgroundPalette.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

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
            .padding(.horizontal, .padding7)
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
                    .overlay {
                        Circle()
                            .strokeBorder(.blackFixed, lineWidth: 1)
                    }

                icon
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(selectedImageSource == source ? Color.whiteFixed : .gray850)
                    .frame(width: 24, height: 24)

                if selectedImageSource == source {
                    Circle()
                        .fill(.black25)
                    icon
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

    private func colorChip(_ hex: String) -> some View {
        Button {
            onColorSelect(hex)
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .overlay {
                    Circle()
                        .strokeBorder(.blackFixed, lineWidth: 1)
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
