//
//  ToppingComponents.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import SwiftUI
import UIComponent

struct ToppingFloatingBar: View {
    let trailingAction: () -> Void

    var body: some View {
        HStack {
            Spacer()
            ToppingCircleButton(
                icon: .icClose,
                foregroundColor: .gray900,
                backgroundColor: .gray50,
                action: trailingAction
            )
        }
        .frame(height: 60)
        .padding(.horizontal, 20)
        .background(.whiteFixed)
    }
}

struct ToppingCircleButton: View {
    let icon: Image
    var foregroundColor: Color?
    let backgroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            iconImage
                .frame(width: 44, height: 44)
                .background(backgroundColor, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var iconImage: some View {
        if let foregroundColor {
            icon
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(foregroundColor)
                .frame(width: 28, height: 28)
        } else {
            icon
                .renderingMode(.original)
                .resizable()
                .frame(width: 28, height: 28)
        }
    }
}

struct ToppingDualActionBar: View {
    let secondaryTitle: String
    let primaryTitle: String
    let secondaryAction: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            actionButton(
                title: secondaryTitle,
                foregroundColor: .gray900,
                backgroundColor: .gray100,
                borderColor: .gray500,
                action: secondaryAction
            )
            actionButton(
                title: primaryTitle,
                foregroundColor: .whiteFixed,
                backgroundColor: .gray900,
                borderColor: .clear,
                action: primaryAction
            )
        }
        .frame(height: 48)
    }

    private func actionButton(
        title: String,
        foregroundColor: Color,
        backgroundColor: Color,
        borderColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .suit(.body01SemiBold)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundColor)
                .overlay {
                    Rectangle()
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct ToppingErrorView: View {
    let title: String
    let message: String
    let actionTitle: String
    let onActionTap: () -> Void
    let onCloseTap: () -> Void

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image.icWarningRound
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(.gray900)
                    .frame(width: 28, height: 28)

                VStack(spacing: 4) {
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
            ToppingFloatingBar(trailingAction: onCloseTap)
        }
    }
}

struct ToppingToast: View {
    var body: some View {
        Text("대상이 배경과 선명하게 구분될수록 깔끔하게 선택돼요")
            .suit(.body02SemiBold)
            .foregroundStyle(.pudding600)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .frame(height: 45)
            .background(.black75)
    }
}
