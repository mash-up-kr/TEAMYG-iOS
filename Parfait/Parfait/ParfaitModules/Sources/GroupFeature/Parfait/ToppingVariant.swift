//
//  ToppingVariant.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import CoreGraphics
import Foundation

/// 토핑 6타입(Left/Right × 1·2·3) 중 하나. 이미지 기울기와 칩 위치만 다르다.
struct ToppingVariant {
    /// 시계방향 각도(SwiftUI `rotationEffect` 기준). 디자인 스펙은 반시계 양수라 부호가 반대다.
    let rotation: CGFloat
    /// Img 아래 끝에서 칩 위 끝까지의 거리(음수 = 겹침).
    let chipOffset: CGFloat

    /// index 로 좌/우가 정해지고, 변형 번호(1·2·3)는 그룹마다 고정 배정된다.
    static func variant(forSide isRight: Bool, number: Int) -> ToppingVariant {
        switch (isRight, number) {
        case (false, 0): ToppingVariant(rotation: -6, chipOffset: -7)  // Left-1
        case (false, 1): ToppingVariant(rotation: -12, chipOffset: -5) // Left-2
        case (false, _): ToppingVariant(rotation: 8, chipOffset: -8)   // Left-3
        case (true, 0): ToppingVariant(rotation: 6, chipOffset: -6)    // Right-1
        case (true, 1): ToppingVariant(rotation: 16, chipOffset: -3)   // Right-2
        case (true, _): ToppingVariant(rotation: 8, chipOffset: -8)    // Right-3
        }
    }

    static let numberCount = 3

    /// 회전한 Img 의 바운딩 박스 한 변 — 칩을 Img 아래에 붙일 때 쓴다.
    var rotatedImageExtent: CGFloat {
        let radians = rotation * .pi / 180
        return ParfaitLayout.toppingImageSize * (abs(cos(radians)) + abs(sin(radians)))
    }

    /// 토핑 프레임(160×160) 안에서 칩 위 끝의 y.
    var chipTopInFrame: CGFloat {
        let imageCenterY = ParfaitLayout.toppingSize / 2 - ParfaitLayout.toppingImageCenterLift
        return imageCenterY + rotatedImageExtent / 2 + chipOffset
    }
}

/// 그룹마다 "한 번 정해지면 안 바뀌는" 값(토핑 변형 번호, 템플릿 그래픽 번호)을 id 에서 뽑아낸다.
///
/// `Hashable.hashValue` 는 프로세스마다 시드가 달라 앱을 껐다 켜면 값이 바뀐다 —
/// "재접속해도 이미 부여된 그래픽은 변경되지 않음" 정책을 지키려면 고정 해시가 필요하다.
/// (서버가 배정값을 내려주면 그 값으로 대체할 것.)
enum StableAssignment {
    /// FNV-1a 64bit.
    static func hash(_ text: String) -> UInt64 {
        var result: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            result ^= UInt64(byte)
            result &*= 0x0000_0100_0000_01b3
        }
        return result
    }

    /// `text` 에서 `0..<count` 범위의 값을 항상 같게 뽑는다.
    static func index(for text: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(hash(text) % UInt64(count))
    }
}
