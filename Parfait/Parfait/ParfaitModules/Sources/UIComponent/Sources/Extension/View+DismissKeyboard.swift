//
//  View+DismissKeyboard.swift
//  UIComponent
//
//  Created by 신상우 on 8/11/26.
//

import SwiftUI
import UIKit

public extension View {
    /// 화면의 첫 응답자를 해제해 키보드를 내린다.
    /// 입력 영역 밖 탭이나 제출 버튼처럼 "키보드를 접고 싶은" 액션에서 호출한다.
    func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
