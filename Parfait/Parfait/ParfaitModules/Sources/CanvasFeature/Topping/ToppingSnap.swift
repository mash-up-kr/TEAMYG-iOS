//
//  ToppingSnap.swift
//  CanvasFeature
//
//  Created by 김남수 on 11/6/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

/// 토핑 이동·회전 중 중앙 정렬·각도 스냅 (#154).
/// 판정은 손가락을 따라가는 원래 배치로 한다 — 스냅된 값으로 재면 한 번 붙은 뒤 떨어지지 않는다.
struct ToppingSnap: Equatable {
    // ponytail: 둘 다 정책 시작값 — 빌드 확인 후 조정 예정.
    static let positionThreshold: CGFloat = 6
    static let angleThreshold: Double = 3
    static let motion: Animation = .easeOut(duration: 0.09)

    /// 세로 중앙선(x = 0.5)에 붙었는지.
    let snapsX: Bool
    /// 가로 중앙선(y = 0.5)에 붙었는지.
    let snapsY: Bool
    /// 붙은 각도 (0°/90°/180°/270° 의 배수). 회전 수는 그대로 둔다.
    let snappedAngle: Double?
    /// 민트 점선은 회전 손가락이 닿아 있는 동안만 — 회전을 끝내고 이동만 이어가면 내린다 (붙은 각도는 유지).
    let showsAngleGuide: Bool

    /// 돌린 적이 없으면 각도는 보지 않는다 — 이동만 할 땐 원래 각도가 0° 여도 민트 점선이 뜨지 않는다.
    init(placement: ToppingPlacement, canvasSize: CGSize, hasRotated: Bool, isRotating: Bool) {
        snapsX = abs(placement.positionX - 0.5) * canvasSize.width <= Self.positionThreshold
        snapsY = abs(placement.positionY - 0.5) * canvasSize.height <= Self.positionThreshold

        let nearestAngle = (placement.rotationDegrees / 90).rounded() * 90
        let isNearAngle = abs(placement.rotationDegrees - nearestAngle) <= Self.angleThreshold
        snappedAngle = hasRotated && isNearAngle ? nearestAngle : nil
        showsAngleGuide = snappedAngle != nil && isRotating
    }

    /// 변형 중이 아닐 때 — 아무것도 붙지 않는다.
    static let none = Self(snapsX: false, snapsY: false, snappedAngle: nil, showsAngleGuide: false)

    private init(snapsX: Bool, snapsY: Bool, snappedAngle: Double?, showsAngleGuide: Bool) {
        self.snapsX = snapsX
        self.snapsY = snapsY
        self.snappedAngle = snappedAngle
        self.showsAngleGuide = showsAngleGuide
    }

    /// 0°/180° 면 수평선, 90°/270° 면 수직선.
    var isAngleHorizontal: Bool {
        guard let snappedAngle else { return false }
        return Int(snappedAngle / 90).isMultiple(of: 2)
    }

    func applied(to placement: ToppingPlacement) -> ToppingPlacement {
        var snapped = placement
        if snapsX { snapped.positionX = 0.5 }
        if snapsY { snapped.positionY = 0.5 }
        if let snappedAngle { snapped.rotationDegrees = snappedAngle }
        return snapped
    }

    /// 축·각도별 새 진입이 하나라도 있으면 햅틱 — 같은 프레임의 동시 진입은 한 번으로 합쳐진다.
    func hasNewEntry(since old: Self) -> Bool {
        (snapsX && !old.snapsX)
            || (snapsY && !old.snapsY)
            || (snappedAngle != nil && snappedAngle != old.snappedAngle)
    }
}

/// 위치 가이드(옐로우 실선, 캔버스 정중앙 고정) + 각도 가이드(민트 점선, 토핑 중심을 지나 캔버스 끝까지).
/// 민트 점선이 옐로우 실선 위. 캔버스 크기 레이어에 깔고, 이동 중 토핑 바로 아래에 둔다.
struct ToppingSnapGuides: View {
    private static let fadeIn = AnyTransition.opacity.animation(.easeOut(duration: 0.1))
    private static let fadeOut = AnyTransition.opacity.animation(.easeOut(duration: 0.15))
    private static let angleDash = StrokeStyle(lineWidth: 1, lineCap: .square, dash: [2.4, 4.8])

    let snap: ToppingSnap
    /// 스냅이 반영된 토핑 중심.
    let center: CGPoint
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            if snap.snapsX {
                positionLine(verticalLine(atX: canvasSize.width / 2))
            }
            if snap.snapsY {
                positionLine(horizontalLine(atY: canvasSize.height / 2))
            }
            if snap.showsAngleGuide, snap.isAngleHorizontal {
                angleLine(horizontalLine(atY: center.y))
            }
            if snap.showsAngleGuide, !snap.isAngleHorizontal {
                angleLine(verticalLine(atX: center.x))
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
        .sensoryFeedback(.impact(weight: .light), trigger: snap) { old, new in
            new.hasNewEntry(since: old)
        }
    }

    private func verticalLine(atX positionX: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: positionX, y: 0))
            path.addLine(to: CGPoint(x: positionX, y: canvasSize.height))
        }
    }

    private func horizontalLine(atY positionY: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: positionY))
            path.addLine(to: CGPoint(x: canvasSize.width, y: positionY))
        }
    }

    private func positionLine(_ line: Path) -> some View {
        line
            .stroke(Color.pudding500, lineWidth: 1)
            .shadow(color: .black5, radius: 2)
            .transition(.asymmetric(insertion: Self.fadeIn, removal: Self.fadeOut))
    }

    private func angleLine(_ line: Path) -> some View {
        line
            .stroke(Color.melon500, style: Self.angleDash)
            .transition(.asymmetric(insertion: Self.fadeIn, removal: Self.fadeOut))
    }
}
