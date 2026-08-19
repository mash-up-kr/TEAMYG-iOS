//
//  ToppingAnalysisLoadingView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/20/26.
//

import SwiftUI
import UIComponent

struct ToppingAnalysisLoadingView: View {
    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: .gap4) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.gray900)

                Text("사진을 편집하고 있어요")
                    .suit(.title03SemiBold)
                    .foregroundStyle(.gray900)

                Text("잠시만 기다려주세요 ⋯")
                    .suit(.body02Regular)
                    .foregroundStyle(.gray500)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(.close)
        }
    }
}
