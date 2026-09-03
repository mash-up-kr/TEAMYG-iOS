//
//  ToppingCutoutResultView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/22/26.
//

import SwiftUI
import UIComponent

struct ToppingCutoutResultView: View {
    let topping: ExtractedTopping
    let onCloseTap: () -> Void
    let onPhotoEditTap: () -> Void
    let onNextTap: () -> Void

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(decorative: topping.image, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: .gap4) {
                    YGButton("사진 편집", variant: .mediumSecondary, fillsWidth: true, action: onPhotoEditTap)
                    YGButton("다음", variant: .mediumPrimary, fillsWidth: true, action: onNextTap)
                }
                .padding(.top, .padding6)
            }
            .padding(.horizontal, .padding7)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(.close, onClose: onCloseTap)
        }
    }
}
