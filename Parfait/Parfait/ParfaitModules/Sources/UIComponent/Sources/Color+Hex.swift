//
//  Color+Hex.swift
//  UIComponent
//
//  Created by 김남수 on 7/3/26.
//

import SwiftUI

public extension Color {
    /// hex 문자열로 색 생성. `"FEE500"` / `"#FEE500"` 지원.
    /// 잘못된 문자열은 디버그에서 assert, 릴리즈에선 검정 폴백.
    init(hex: String, alpha: Double = 1) {
        let hexString = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard hexString.count == 6, let value = UInt64(hexString, radix: 16) else {
            assertionFailure("잘못된 hex 문자열: \(hex)")
            self = .black
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: alpha
        )
    }
}
