//
//  CanvasBackgroundPalette.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import Common
import Core
import CoreGraphics
import SwiftUI
import UIComponent

struct CanvasBackgroundPalette: View {
    static let height: CGFloat = 60

    private static let colors = CanvasPalette.all

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
                    CanvasColorChip(hex: hex, isSelected: CanvasPalette.matches(selectedColorHex, hex)) {
                        onColorSelect(hex)
                    }
                }
            }
            .padding(.vertical, .padding2)
            .padding(.leading, .padding7)
            .padding(.top, .padding6)
        }
        .scrollIndicators(.hidden)
        .frame(height: Self.height)
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
                    CanvasBackgroundView(background: background, showsLoadingIndicator: false)
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
}

/// 원형 색 칩 — 배경 팔레트와 텍스트 색 팝오버가 같은 모양을 쓴다.
struct CanvasColorChip: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .overlay {
                    Circle()
                        .strokeBorder(.black5, lineWidth: 1)
                }
                .overlay {
                    if isSelected {
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
