//
//  ToppingAnalysisErrorView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/22/26.
//

import SwiftUI
import UIComponent

struct ToppingAnalysisErrorView: View {
    let onCloseTap: () -> Void

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: .gap5) {
                Image.icWarningRound
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(.gray900)
                    .frame(width: 28, height: 28)

                VStack(spacing: .gap2) {
                    Text("사진 편집에 실패했어요")
                        .suit(.title03SemiBold)
                        .foregroundStyle(.gray900)

                    Text("다른 사진을 선택하거나 다시 시도해 주세요")
                        .suit(.body02Regular)
                        .foregroundStyle(.gray500)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 233)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(.close, onClose: onCloseTap)
        }
    }
}
