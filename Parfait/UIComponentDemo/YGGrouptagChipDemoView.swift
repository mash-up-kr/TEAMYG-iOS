//
//  YGGrouptagChipDemoView.swift
//  UIComponentDemo
//
//  Created by 신상우 on 7/15/26.
//

import SwiftUI
import UIComponent

/// YGGrouptagChip 데모.
/// Nametag 타입별(2개씩 묶여 6색) Timestamp 색 매핑을 한눈에 확인한다.
struct YGGrouptagChipDemoView: View {
    private let rows: [(name: String, type: YGNametagChip.NametagType)] = [
        ("잠탈감금", .type1),
        ("팀와지", .type3),
        ("팀장은연경...", .type5),
        ("잠탈감금2", .type7),
        ("다섯글자임", .type9),
        ("이름", .type11)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(rows, id: \.type.rawValue) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type \(row.type.rawValue)·\(row.type.rawValue + 1)")
                            .font(.subheadline)
                            .foregroundStyle(.gray400)
                        YGGrouptagChip(name: row.name, timestamp: "3분전", type: row.type)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("YGGrouptagChip")
    }
}

#Preview {
    NavigationStack {
        YGGrouptagChipDemoView()
    }
}
