//
//  ToppingVariant.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import CoreGraphics
import Foundation

/// 토핑 6타입(Left/Right × 1·2·3) 중 하나. 이미지 기울기·위치와 칩 위치만 다르다.
struct ToppingVariant {
    /// 시계방향 각도(SwiftUI `rotationEffect` 기준). 디자인 스펙은 반시계 양수라 부호가 반대다.
    let rotation: CGFloat
    /// 디자인 스펙의 Image Translate — 회전한 Img 의 바운딩 박스 좌상단이 놓일 프레임 안 좌표.
    let imageBoxOrigin: CGPoint
    /// Img 아래 끝에서 칩 위 끝까지의 거리(음수 = 겹침).
    let chipOffset: CGFloat

    /// index 로 좌/우가 정해지고, 변형 번호(1·2·3)는 그룹마다 고정 배정된다.
    static func variant(forSide isRight: Bool, number: Int) -> ToppingVariant {
        switch (isRight, number) {
        case (false, 0): ToppingVariant(rotation: -6, imageBoxOrigin: CGPoint(x: 26, y: 16), chipOffset: -7)
        case (false, 1): ToppingVariant(rotation: -12, imageBoxOrigin: CGPoint(x: 24, y: 11), chipOffset: -5)
        case (false, _): ToppingVariant(rotation: 8, imageBoxOrigin: CGPoint(x: 25, y: 16), chipOffset: -8)
        case (true, 0): ToppingVariant(rotation: 6, imageBoxOrigin: CGPoint(x: 26, y: 16), chipOffset: -6)
        case (true, 1): ToppingVariant(rotation: 16, imageBoxOrigin: CGPoint(x: 22, y: 8), chipOffset: -3)
        case (true, _): ToppingVariant(rotation: 8, imageBoxOrigin: CGPoint(x: 25, y: 16), chipOffset: -8)
        }
    }

    static let numberCount = 3

    /// 회전한 Img 의 바운딩 박스 한 변.
    var rotatedImageExtent: CGFloat {
        let radians = rotation * .pi / 180
        return ParfaitLayout.toppingImageSize * (abs(cos(radians)) + abs(sin(radians)))
    }

    /// 회전한 바운딩 박스의 중심 — 회전 전 96×96 프레임을 이 중심에 맞추면 스펙 자리에 놓인다.
    /// (`rotationEffect` 는 레이아웃 크기를 바꾸지 않으므로 중심만 맞추면 된다.)
    var imageCenterInFrame: CGPoint {
        CGPoint(
            x: imageBoxOrigin.x + rotatedImageExtent / 2,
            y: imageBoxOrigin.y + rotatedImageExtent / 2
        )
    }

    /// 토핑 프레임(160×160) 안에서 칩 위 끝의 y — Img 아래 끝에서 `chipOffset` 만큼.
    var chipTopInFrame: CGFloat {
        imageBoxOrigin.y + rotatedImageExtent + chipOffset
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
