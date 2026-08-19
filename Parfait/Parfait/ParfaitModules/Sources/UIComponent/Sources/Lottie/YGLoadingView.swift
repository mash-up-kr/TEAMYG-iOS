//
//  YGLoadingView.swift
//  UIComponent
//
//  Created by 김남수 on 8/19/26.
//

import SwiftUI

/// 공용 로딩 뷰. 전체 화면 딤(black75) 위에 로딩 스피너를 센터 정렬로 띄우고 터치를 막는다.
/// 사용: 표시할 화면에 `.overlay { if isLoading { YGLoadingView() } }`
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

#Preview {
    Color.orange
        .ignoresSafeArea()
        .overlay { YGLoadingView() }
}
