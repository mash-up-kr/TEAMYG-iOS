//
//  NoticeNewChip.swift
//  SettingFeature
//
//  Created by 박서연 on 11/17/26.
//

import SwiftUI
import UIComponent

struct NoticeNewChip: View {
    var body: some View {
        Text("NEW")
            .suit(.caption01Medium)
            .foregroundStyle(.cherry700)
            .padding(.horizontal, .padding2)
            .padding(.vertical, .padding1)
            .background(.cherry100)
            .fixedSize()
    }
}
