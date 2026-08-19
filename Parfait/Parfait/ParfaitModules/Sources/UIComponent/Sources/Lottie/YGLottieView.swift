//
//  YGLottieView.swift
//  UIComponent
//
//  Created by 김남수 on 8/19/26.
//

import Lottie
import SwiftUI

/// UIComponent 번들에 포함된 로띠 애니메이션.
public enum YGLottieAnimation {
    /// 밝은 톤 로딩 스피너(흰 점) — 어두운 배경 위.
    case loadingLight
    /// 어두운 톤 로딩 스피너(회색 점) — 밝은 배경 위.
    case loadingDark
    /// 앱 로고.
    case logo

    fileprivate var fileName: String {
        switch self {
        case .loadingLight: "Lottie_Loading_Light"
        case .loadingDark: "Lottie_Loading_Dark"
        case .logo: "Lottie-Logo"
        }
    }
}

/// 로띠 애니메이션을 재생하는 공용 뷰. 크기는 부모가 정한다(`.frame`).
///
/// ```swift
/// YGLottieView(.loadingDark)                              // 무한 반복
/// YGLottieView(.logo, loops: false) { showsNextScreen() } // 한 번만 재생 → 완료 콜백
/// ```
public struct YGLottieView: View {
    private let animation: YGLottieAnimation
    private let loops: Bool
    private let onFinish: (() -> Void)?

    /// - Parameters:
    ///   - animation: 재생할 애니메이션.
    ///   - loops: `true` 면 무한 반복, `false` 면 한 번만 재생.
    ///   - onFinish: 재생이 끝났을 때 호출(무한 반복이면 호출되지 않는다).
    public init(_ animation: YGLottieAnimation, loops: Bool = true, onFinish: (() -> Void)? = nil) {
        self.animation = animation
        self.loops = loops
        self.onFinish = onFinish
    }

    public var body: some View {
        // ponytail: 진행률·재생 제어 없음. 필요해지면 LottieView 모디파이어를 노출
        LottieView { try await DotLottieFile.named(animation.fileName, bundle: .module) }
            .playing(loopMode: loops ? .loop : .playOnce)
            .animationDidFinish { _ in onFinish?() }
    }
}

#Preview("로딩 — 밝은 배경") {
    YGLottieView(.loadingDark)
        .frame(width: 80, height: 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
}

#Preview("로딩 — 어두운 배경") {
    YGLottieView(.loadingLight)
        .frame(width: 80, height: 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
}

#Preview("로고") {
    YGLottieView(.logo, loops: false)
        .frame(width: 202, height: 230)
}
