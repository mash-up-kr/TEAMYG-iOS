//
//  GroupDateHeader.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import SwiftUI
import UIComponent

/// 그룹 목록 좌상단의 오늘 날짜 배지. 예: `December 31 (Wed)`.
struct GroupDateHeader: View {
    let date: Date

    /// 디자인 표기가 영문 월·요일이라 로케일을 고정한다.
    private static let locale = Locale(identifier: "en_US_POSIX")

    private var monthAndDay: String {
        date.formatted(.dateTime.locale(Self.locale).month(.wide).day())
    }

    private var weekday: String {
        "(" + date.formatted(.dateTime.locale(Self.locale).weekday(.abbreviated)) + ")"
    }

    var body: some View {
        HStack(spacing: .gap3) {
            Text(monthAndDay)
                .suit(.body01Regular)
                .foregroundStyle(.gray800)
            Text(weekday)
                .suit(.body01Regular)
                .foregroundStyle(.gray300)
        }
        .padding(.vertical, .padding3)
        .padding(.horizontal, .padding4)
        .background(.whiteFixed)
        .overlay { Rectangle().stroke(.gray600, lineWidth: 1) }
    }
}

#Preview {
    GroupDateHeader(date: .now)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 20)
        .background(.whiteFixed)
}
