//
//  ToppingErrorView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import SwiftUI
import UIComponent

struct ToppingErrorView: View {
    let title: String
    let message: String
    let actionTitle: String
    let onActionTap: () -> Void

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
                    Text(title)
                        .suit(.title03SemiBold)
                        .foregroundStyle(.gray900)
                    Text(message)
                        .suit(.body02Regular)
                        .foregroundStyle(.gray500)
                        .multilineTextAlignment(.center)
                }

                YGButton(actionTitle, variant: .large, action: onActionTap)
            }
            .frame(width: 206)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(.close)
        }
    }
}
