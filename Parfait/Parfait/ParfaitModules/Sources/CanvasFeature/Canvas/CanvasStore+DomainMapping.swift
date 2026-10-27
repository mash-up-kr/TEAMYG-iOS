//
//  CanvasStore+DomainMapping.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import UIComponent

public extension CanvasStore {
    struct CanvasImageBorder: Equatable, Sendable {
        public let colorHex: String
        public let width: Double

        public init(colorHex: String, width: Double) {
            self.colorHex = colorHex
            self.width = width
        }
    }
}

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
    static let empty = CanvasStore.CanvasContent(background: .unset)

    init(_ parfait: Parfait) {
        self.init(
            background: parfait.background.map(CanvasStore.CanvasBackground.init) ?? .unset,
            images: parfait.toppings.map(CanvasStore.CanvasImage.init),
            texts: parfait.texts.map(CanvasStore.CanvasText.init)
        )
    }
}

extension CanvasStore.CanvasBackground {
    static let unset = CanvasStore.CanvasBackground.color(hex: CanvasPalette.white)

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
            border: CanvasStore.CanvasImageBorder(topping.border),
            isMine: topping.ownerType == .currentUser
        )
    }
}

extension CanvasStore.CanvasText {
    /// 색이 깨졌으면 White, 팔레트 밖 색이면 글자색만 그대로 두고 배경은 White 짝을 쓴다.
    init(_ placedText: PlacedText) {
        let textHex = placedText.colorHex ?? TextToppingColor.white.textHex
        self.init(
            id: placedText.id,
            text: placedText.text,
            positionX: placedText.positionX,
            positionY: placedText.positionY,
            positionZ: Double(placedText.positionZ),
            scale: placedText.scale,
            rotation: placedText.rotation,
            textHex: textHex,
            fillHex: (TextToppingColor(textHex: textHex) ?? .white).fillHex,
            type: TextToppingType(isFill: placedText.isFill, isStroke: placedText.isStroke),
            alignment: placedText.alignment,
            isMine: placedText.ownerType == .currentUser
        )
    }
}

extension CanvasStore.CanvasImageBorder {
    init?(_ border: ToppingBorderStyle) {
        guard case .solid(let colorHex, let width) = border else { return nil }
        self.init(colorHex: colorHex, width: width)
    }
}
