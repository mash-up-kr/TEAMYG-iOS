//
//  SplashView.swift
//  Parfait
//
//  Created by 김남수 on 8/19/26.
//

import SwiftUI
import UIComponent

/// 앱 시작 스플래시 — 화면 가운데서 로고 애니메이션을 1회 재생하고 `onFinish` 를 호출한다.
struct SplashView: View {
    /// 애니메이션(3.5초)이 끝나도 콜백이 오지 않는 최악의 경우 대비 — 스플래시에 갇히지 않게 한다.
    private static let fallbackTimeout = Duration.seconds(6)

    private let onFinish: () -> Void
    /// 완료 콜백과 타임아웃 중 먼저 온 하나만 통과시킨다.
    @State private var hasFinished = false

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    var body: some View {
        YGLottieView(.logo, loops: false, onFinish: finish)
            .frame(width: 202, height: 230)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.gray50)
            .task {
                try? await Task.sleep(for: Self.fallbackTimeout)
                finish()
            }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish()
    }
}

#Preview {
    SplashView { }
}
