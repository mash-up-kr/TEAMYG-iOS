//
//  ToppingPlacement.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import CoreGraphics
import Foundation

struct ToppingPlacement: Equatable, Sendable {
    var positionX: Double = 0.5
    var positionY: Double = 0.5
    var scale: Double = 1
    var rotationDegrees: Double = 0
}

extension ToppingPlacement {
    static let maximumScale: Double = 3
    static let minimumShortSide: CGFloat = 48

    static func initial(toppingPixelSize: CGSize, canvasSize: CGSize) -> Self {
        var placement = Self()
        placement.scale = minimumScale(toppingPixelSize: toppingPixelSize, canvasSize: canvasSize)
        return placement
    }

    static func minimumScale(toppingPixelSize: CGSize, canvasSize: CGSize) -> Double {
        let shortSideRatio = shortSideRatio(of: toppingPixelSize)
        let baseLongSide = baseLongSide(in: canvasSize)
        guard shortSideRatio > 0, baseLongSide > 0 else { return 1 }

        return max(1, Double(minimumShortSide / (baseLongSide * shortSideRatio)))
    }

    static func baseLongSide(in canvasSize: CGSize) -> CGFloat {
        canvasSize.width * CanvasArea.toppingBaseLongSideRatio
    }

    func center(in canvasSize: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(positionX) * canvasSize.width, y: CGFloat(positionY) * canvasSize.height)
    }

    func longSide(in canvasSize: CGSize) -> CGFloat {
        Self.baseLongSide(in: canvasSize) * CGFloat(scale)
    }

    func renderedSize(toppingPixelSize: CGSize, canvasSize: CGSize) -> CGSize {
        CanvasArea.toppingSize(pixelSize: toppingPixelSize, longSide: longSide(in: canvasSize))
    }

    func moved(by translation: CGSize, in canvasSize: CGSize) -> Self {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return self }

        var moved = self
        moved.positionX += Double(translation.width / canvasSize.width)
        moved.positionY += Double(translation.height / canvasSize.height)
        return moved
    }

    func magnified(by factor: Double, toppingPixelSize: CGSize, canvasSize: CGSize) -> Self {
        let minimumScale = Self.minimumScale(toppingPixelSize: toppingPixelSize, canvasSize: canvasSize)

        var magnified = self
        magnified.scale = max(min(scale * factor, Self.maximumScale), minimumScale)
        return magnified
    }

    func rotated(by degrees: Double) -> Self {
        var rotated = self
        rotated.rotationDegrees += degrees
        return rotated
    }

    private static func shortSideRatio(of pixelSize: CGSize) -> CGFloat {
        let longSide = max(pixelSize.width, pixelSize.height)
        guard longSide > 0 else { return 1 }
        return min(pixelSize.width, pixelSize.height) / longSide
    }
}

extension ToppingPlacement {
    init(_ canvasImage: CanvasStore.CanvasImage) {
        self.init(
            positionX: canvasImage.positionX,
            positionY: canvasImage.positionY,
            scale: canvasImage.scale,
            rotationDegrees: canvasImage.rotation
        )
    }
}

struct ToppingPlacementEditor: Equatable, Sendable {
    private(set) var placement = ToppingPlacement()
    private(set) var canvasSize: CGSize = .zero
    private var toppingPixelSize: CGSize = .zero
    private var hasInitialPlacement = false

    mutating func prepare(toppingPixelSize: CGSize) {
        guard self.toppingPixelSize != toppingPixelSize else { return }
        self.toppingPixelSize = toppingPixelSize
        hasInitialPlacement = false
    }

    mutating func reset() {
        self = Self()
    }

    var renderedSize: CGSize {
        placement.renderedSize(toppingPixelSize: toppingPixelSize, canvasSize: canvasSize)
    }

    var center: CGPoint {
        placement.center(in: canvasSize)
    }

    mutating func apply(_ intent: ToppingAddStore.Intent) {
        switch intent {
        case .placementCanvasResized(let canvasSize): resize(to: canvasSize)
        case .placementMoved(let translation): placement = placement.moved(by: translation, in: canvasSize)
        case .placementScaled(let factor): magnify(by: factor)
        case .placementRotated(let degrees): placement = placement.rotated(by: degrees)
        default: break
        }
    }

    func placementValues(zOrder: Int) -> ToppingPlacementValues {
        ToppingPlacementValues(
            positionX: placement.positionX,
            positionY: placement.positionY,
            positionZ: zOrder,
            scale: placement.scale,
            rotation: placement.rotationDegrees
        )
    }

    func magnifying(by factor: Double) -> ToppingPlacement {
        placement.magnified(by: factor, toppingPixelSize: toppingPixelSize, canvasSize: canvasSize)
    }

    private mutating func resize(to canvasSize: CGSize) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        self.canvasSize = canvasSize

        guard hasInitialPlacement else {
            placement = .initial(toppingPixelSize: toppingPixelSize, canvasSize: canvasSize)
            hasInitialPlacement = true
            return
        }
        magnify(by: 1)
    }

    private mutating func magnify(by factor: Double) {
        placement = magnifying(by: factor)
    }
}
