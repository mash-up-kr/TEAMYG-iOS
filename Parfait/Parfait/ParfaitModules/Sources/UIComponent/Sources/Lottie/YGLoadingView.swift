//
//  YGLoadingView.swift
//  UIComponent
//
//  Created by 김남수 on 8/19/26.
//

import SwiftUI

/// 공용 로딩 뷰. 전체 화면 딤(black75) 위에 로띠와 안내 문구를 센터 정렬로 띄우고 터치를 막는다.
/// 보통은 직접 쓰지 않고 `.ygLoading(_:)` 으로 얹는다.
public struct YGLoadingView: View {
    private let animation: YGLottieAnimation
    private let message: String?

    /// - Parameters:
    ///   - animation: 딤 위에 재생할 로띠. 기본은 밝은 톤 스피너.
    ///   - message: 로띠 아래 안내 문구. `nil` 이면 로띠만 띄운다.
    public init(animation: YGLottieAnimation = .loadingLight, message: String? = nil) {
        self.animation = animation
        self.message = message
    }

    public var body: some View {
        ZStack {
            Color.black75.ignoresSafeArea()
            VStack(spacing: .gap3) {
                YGLottieView(animation)
                    .frame(width: animationSize.width, height: animationSize.height)
                if let message {
                    Text(message)
                        .suit(.body02Regular)
                        .foregroundStyle(Color.gray200)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    /// 로띠마다 시안 크기가 다르다 — 토핑은 C-001-Loading 의 90×106, 스피너류는 44×44.
    private var animationSize: CGSize {
        switch animation {
        case .topping: CGSize(width: 90, height: 106)
        default: CGSize(width: 44, height: 44)
        }
    }
}

public extension View {
    /// 로딩 중일 때 전체 화면 딤 + 스피너를 얹는다(페이드 인·아웃). 딤이 화면 전체를 덮도록 **화면 루트 뷰**에 붙일 것.
    ///
    /// ```swift
    /// content
    ///     .ygLoading(store.state.isLoading)
    /// ```
    func ygLoading(_ isLoading: Bool) -> some View {
        overlay {
            // 애니메이션을 오버레이 안으로 한정 — 본문 레이아웃까지 같이 움직이지 않게 한다.
            ZStack {
                if isLoading {
                    YGLoadingView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
    }
}

#Preview {
    @Previewable @State var isLoading = false

    Button("로딩 \(isLoading ? "끄기" : "켜기")") { isLoading.toggle() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.gray100)
        .ygLoading(isLoading)
}

#Preview("토핑 로딩") {
    YGLoadingView(
        animation: .topping,
        message: "캔버스를 불러오는 중이에요\n고화질일수록 더 오래 걸릴 수 있어요"
    )
}
