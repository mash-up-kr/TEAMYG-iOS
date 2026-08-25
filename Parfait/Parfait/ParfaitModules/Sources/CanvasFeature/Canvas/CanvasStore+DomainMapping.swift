//
//  CanvasStore+DomainMapping.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import UIComponent

extension CalendarDate {
    init(_ date: ParfaitDate) {
        self.init(year: date.year, month: date.month, day: date.day)
    }

    var parfaitDate: ParfaitDate {
        ParfaitDate(year: year, month: month, day: day)
    }
}

extension NametagChip {
    /// 배정되지 않은 그룹원은 첫 번째 계열로 보여준다.
    var chipType: YGNametagChip.NametagType {
        guard let number, let type = YGNametagChip.NametagType(rawValue: number) else {
            return .type1
        }
        return type
    }
}

extension CanvasStore.CanvasContent {
    /// 배경을 설정하지 않은 캔버스의 바닥은 흰색이다 (확정 규약).
    init(_ parfait: Parfait) {
        self.init(
            background: parfait.background.map(CanvasStore.CanvasBackground.init) ?? .color(hex: "#FFFFFF"),
            images: parfait.toppings.map(CanvasStore.CanvasImage.init)
        )
    }
}

extension CanvasStore.CanvasBackground {
    init(_ background: ParfaitBackground) {
        switch background {
        case .color(let hex): self = .color(hex: hex)
        case .image(let url): self = .image(url: url)
        }
    }
}

extension CanvasStore.CanvasImage {
    init(_ topping: PlacedTopping) {
        self.init(
            id: topping.id,
            imageURL: topping.imageURL,
            positionX: topping.positionX,
            positionY: topping.positionY,
            positionZ: Double(topping.positionZ),
            scale: topping.scale,
            rotation: topping.rotation,
            border: CanvasStore.CanvasImageBorder(topping.border)
        )
    }
}

extension CanvasStore.CanvasImageBorder {
    init?(_ border: ToppingBorderStyle) {
        guard case .solid(let colorHex, let width) = border else { return nil }
        self.init(colorHex: colorHex, width: width)
    }
}
