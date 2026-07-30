//
//  YGWebView.swift
//  UIComponent
//
//  Created by 김남수 on 7/28/26.
//

import SwiftUI
import WebKit

/// 상단에 `YGTopBar.detail` 을 두고 나머지 영역 전체를 웹으로 채우는 공용 웹뷰 화면.
///
/// ```swift
/// YGWebView(title: "이용약관", url: termsURL)
/// ```
public struct YGWebView: View {
    private let title: String
    private let url: URL

    /// - Parameters:
    ///   - title: 상단 바에 표시할 타이틀.
    ///   - url: 표시할 페이지 주소.
    public init(title: String, url: URL) {
        self.title = title
        self.url = url
    }

    public var body: some View {
        // ponytail: iOS 26 네이티브 WebView. 로딩 인디케이터·에러 화면·JS 브릿지 없음, 필요해지면 WebPage 로 교체
        WebView(url: url)
            .ygTopBar(.detail(title: title))
    }
}

#Preview {
    YGWebView(title: "이용약관", url: URL(string: "https://www.apple.com")!)
}
