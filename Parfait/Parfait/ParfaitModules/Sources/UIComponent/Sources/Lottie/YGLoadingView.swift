//
//  YGLoadingView.swift
//  UIComponent
//
//  Created by 김남수 on 8/19/26.
//

import SwiftUI

/// 공용 로딩 뷰. 전체 화면 딤(black75) 위에 로딩 스피너를 센터 정렬로 띄우고 터치를 막는다.
/// 보통은 직접 쓰지 않고 `.ygLoading(_:)` 으로 얹는다.
public struct YGLoadingView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.black75.ignoresSafeArea()
            YGLottieView(.loadingLight)
                .frame(width: 44, height: 44)
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
