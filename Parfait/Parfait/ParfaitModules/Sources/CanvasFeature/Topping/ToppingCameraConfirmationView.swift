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
    let photoData: Data?
    let onRetakeTap: () -> Void
    let onNextTap: () -> Void

    @State private var capturedImage: UIImage?

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: 0) {
                capturedImageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: .gap4) {
                    YGButton("다시 찍기", variant: .mediumSecondary, fillsWidth: true, action: onRetakeTap)
                    YGButton("다음", variant: .mediumPrimary, fillsWidth: true, action: onNextTap)
                }
                .padding(.top, .padding6)
            }
            .padding(.horizontal, .padding7)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(.close)
        }
        .task(id: photoData) {
            capturedImage = await Self.decodeImage(from: photoData)
        }
    }

    @ViewBuilder
    private var capturedImageView: some View {
        if let capturedImage {
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFit()
        } else {
            Color.gray100
        }
    }

    private static func decodeImage(from photoData: Data?) async -> UIImage? {
        guard let photoData else { return nil }
        return await Task.detached(priority: .userInitiated) {
            UIImage(data: photoData)?.preparingForDisplay()
        }.value
    }
}
