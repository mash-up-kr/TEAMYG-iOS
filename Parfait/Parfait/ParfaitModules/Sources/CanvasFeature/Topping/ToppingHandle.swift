//
//  ToppingHandle.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/27/26.
//

import SwiftUI
import UIComponent

enum ToppingHandle {
    static let length: CGFloat = 44
    static let circleLength: CGFloat = 28
    static let iconLength: CGFloat = 18
    static let cornerOffset: CGFloat = 22
}

struct ToppingHandleIcon: View {
    let icon: Image

    init(_ icon: Image) {
        self.icon = icon
    }

    var body: some View {
        icon
            .renderingMode(.template)
            .resizable()
            .frame(width: ToppingHandle.iconLength, height: ToppingHandle.iconLength)
            .foregroundStyle(.gray900)
            .frame(width: ToppingHandle.circleLength, height: ToppingHandle.circleLength)
            .background(.whiteFixed, in: .circle)
            .overlay {
                Circle()
                    .strokeBorder(.black5, lineWidth: 1)
            }
            .frame(width: ToppingHandle.length, height: ToppingHandle.length)
            .contentShape(.rect)
    }
}
