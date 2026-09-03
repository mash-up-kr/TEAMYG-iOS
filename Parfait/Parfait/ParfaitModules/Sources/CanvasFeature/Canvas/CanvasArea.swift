//
//  CanvasArea.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics

enum CanvasArea {
    static let aspectRatio: CGFloat = 9 / 16
    static let menuBarHeight: CGFloat = 44
    static let toppingBaseLongSideRatio: CGFloat = 0.4

    static func width(fitting available: CGSize) -> CGFloat {
        let heightForBoard = max(available.height - menuBarHeight + 1, 0)
        return min(available.width, heightForBoard * aspectRatio)
    }

    static func size(fitting available: CGSize) -> CGSize {
        let width = width(fitting: available)
        return CGSize(width: width, height: width / aspectRatio)
    }

    /// 긴 변을 `longSide` 에 맞추고 짧은 변은 원본 비율대로 — 정규화 `scale` 규약(`canvas-policy.md` §5.7)의 역산이다.
    static func toppingSize(pixelSize: CGSize, longSide: CGFloat) -> CGSize {
        let pixelLongSide = max(pixelSize.width, pixelSize.height)
        guard pixelLongSide > 0 else { return CGSize(width: longSide, height: longSide) }

        let shortSide = longSide * (min(pixelSize.width, pixelSize.height) / pixelLongSide)
        return pixelSize.width >= pixelSize.height
            ? CGSize(width: longSide, height: shortSide)
            : CGSize(width: shortSide, height: longSide)
    }
}
