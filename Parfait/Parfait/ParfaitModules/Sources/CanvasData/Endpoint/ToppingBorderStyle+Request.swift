//
//  ToppingBorderStyle+Request.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import CanvasDomain

struct ToppingBorderRequestFields {
    let type: String
    let color: String?
    let width: Double?
}

extension ToppingBorderStyle {
    var requestFields: ToppingBorderRequestFields {
        switch self {
        case .none:
            ToppingBorderRequestFields(type: "NONE", color: nil, width: nil)
        case .solid(let colorHex, let width):
            ToppingBorderRequestFields(type: "SOLID", color: colorHex, width: width)
        }
    }
}
