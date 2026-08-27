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
    /// 배치 화면에 처음 놓일 때 짧은 변이 이보다 얇지 않도록 기본 배율을 키운다.
    /// **초기값 계산에만 쓴다** — 사용자가 직접 조절하는 배율에는 상·하한이 없다 (2026-08-27 확정).
    /// 런타임 클램프로 되살아나지 않도록 `initial(...)` 밖으로 내보내지 않는다.
    private static let defaultMinimumShortSide: CGFloat = 48

    /// 배치 화면 진입 시의 기본 배치 — 중앙, 긴 변이 캔버스 너비의 40%.
    static func initial(toppingPixelSize: CGSize, canvasSize: CGSize) -> Self {
        var placement = Self()
        placement.scale = defaultScale(toppingPixelSize: toppingPixelSize, canvasSize: canvasSize)
        return placement
    }

    /// 기본 배율. 가늘고 긴 토핑은 긴 변을 40%에 맞추면 짧은 변이 너무 얇아져서 그만큼 키워 준다.
    private static func defaultScale(toppingPixelSize: CGSize, canvasSize: CGSize) -> Double {
        let shortSideRatio = shortSideRatio(of: toppingPixelSize)
        let baseLongSide = baseLongSide(in: canvasSize)
        guard shortSideRatio > 0, baseLongSide > 0 else { return 1 }

        return max(1, Double(defaultMinimumShortSide / (baseLongSide * shortSideRatio)))
    }

    private static func baseLongSide(in canvasSize: CGSize) -> CGFloat {
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

    /// 사용자가 직접 조절하는 배율에는 상·하한이 없다 (2026-08-27 확정).
    func magnified(by factor: Double) -> Self {
        var magnified = self
        magnified.scale = scale * factor
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
    func handleCenter(
        horizontal: CGFloat,
        vertical: CGFloat,
        renderedSize: CGSize,
        cornerOffset: CGFloat,
        in canvasSize: CGSize
    ) -> CGPoint {
        let corner = CGSize(
            width: horizontal * (renderedSize.width / 2 + cornerOffset),
            height: vertical * (renderedSize.height / 2 + cornerOffset)
        )
        let radians = rotationDegrees * .pi / 180
        let placementCenter = center(in: canvasSize)

        return CGPoint(
            x: placementCenter.x + corner.width * cos(radians) - corner.height * sin(radians),
            y: placementCenter.y + corner.width * sin(radians) + corner.height * cos(radians)
        )
    }

    func magnification(from startLocation: CGPoint, to location: CGPoint, in canvasSize: CGSize) -> Double {
        let placementCenter = center(in: canvasSize)
        let startDistance = hypot(startLocation.x - placementCenter.x, startLocation.y - placementCenter.y)
        let currentDistance = hypot(location.x - placementCenter.x, location.y - placementCenter.y)
        guard startDistance > 0 else { return 1 }

        return Double(currentDistance / startDistance)
    }

    func rotation(from startLocation: CGPoint, to location: CGPoint, in canvasSize: CGSize) -> Double {
        let placementCenter = center(in: canvasSize)
        let startAngle = atan2(startLocation.y - placementCenter.y, startLocation.x - placementCenter.x)
        let currentAngle = atan2(location.y - placementCenter.y, location.x - placementCenter.x)
        let degrees = Double(currentAngle - startAngle) * 180 / .pi

        return remainder(degrees, 360)
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

    mutating func apply(_ intent: ToppingAddStore.Intent) {
        switch intent {
        case .placementCanvasResized(let canvasSize): resize(to: canvasSize)
        case .placementMoved(let translation): placement = placement.moved(by: translation, in: canvasSize)
        case .placementScaled(let factor): placement = magnifying(by: factor)
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
        placement.magnified(by: factor)
    }

    /// 캔버스 크기가 정해질 때 첫 배치를 잡는다. 이미 잡혀 있으면 `scale` 은 캔버스 대비 비율이라 손댈 게 없다.
    private mutating func resize(to canvasSize: CGSize) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        self.canvasSize = canvasSize

        guard !hasInitialPlacement else { return }
        placement = .initial(toppingPixelSize: toppingPixelSize, canvasSize: canvasSize)
        hasInitialPlacement = true
    }
}
