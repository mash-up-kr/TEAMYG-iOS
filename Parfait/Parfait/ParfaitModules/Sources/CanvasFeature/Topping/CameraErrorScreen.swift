//
//  CameraErrorScreen.swift
//  CanvasFeature
//
//  Created by 김남수 on 9/7/26.
//

import SwiftUI
import UIComponent

/// 카메라 에러 전용 풀스크린 스캐폴드 — 흰 배경 + 상단 닫기 바만 얹는다.
/// 에러 UI 자체는 `YGErrorView` 가 그린다.
struct CameraErrorScreen: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            YGErrorView(
                title: title,
                message: message,
                buttonTitle: buttonTitle,
                action: action
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(.close)
        }
    }
}

#Preview {
    CameraErrorScreen(
        title: "카메라 권한이 없어요",
        message: "설정에서 카메라 권한을 허용해 주세요",
        buttonTitle: "설정으로 이동"
    ) {}
}
