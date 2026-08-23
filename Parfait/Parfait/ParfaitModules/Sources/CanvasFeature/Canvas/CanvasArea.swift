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
}
