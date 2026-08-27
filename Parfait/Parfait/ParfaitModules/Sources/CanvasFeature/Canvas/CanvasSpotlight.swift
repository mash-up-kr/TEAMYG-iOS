//
//  CanvasSpotlight.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

import CanvasDomain
import Common
import Foundation
import UIComponent

extension CanvasStore {
    struct ToppingAuthor: Equatable, Sendable {
        let nickname: String
        let nametagChip: NametagChip
        let placedAt: Date?

        init(_ topping: PlacedTopping) {
            nickname = topping.placedBy.nickname
            nametagChip = topping.placedBy.nametagChip
            placedAt = topping.createdAt
        }
    }

    public struct SpotlightToast: Equatable, Sendable {
        let nickname: String
        let nametagChip: NametagChip
        let relativeTimeText: String

        init(author: ToppingAuthor, now: Date) {
            nickname = author.nickname
            nametagChip = author.nametagChip
            relativeTimeText = RelativeTimeText.string(from: author.placedAt ?? now, now: now)
        }
    }
}

extension CanvasStore.State {
    /// 과거 캔버스는 열람 전용이고, Spotlight 중에는 다른 토핑으로 바로 넘어가지 않는다 (`canvas-policy.md` §4.2).
    func tappableTopping(_ toppingID: Int) -> CanvasStore.CanvasImage? {
        guard !isClosedCanvas, spotlightedToppingID == nil else { return nil }
        return canvasContent?.images.first { $0.id == toppingID }
    }
}

extension CanvasStore.SpotlightToast {
    /// 네임태그가 배정되지 않은 작성자(탈퇴·나간 사용자 포함)는 강조할 색이 없어 한 줄로 보여준다.
    var toastItem: YGToastItem {
        guard let number = nametagChip.number,
              let nametagType = YGNametagChip.NametagType(rawValue: number)
        else {
            return YGToastItem(kind: .normal, message: "\(nickname)\(body)")
        }
        return YGToastItem(kind: .alert(username: nickname, nametagType: nametagType), message: body)
    }

    private var body: String {
        " 님이 \(relativeTimeText)에 쌓았어요"
    }
}
