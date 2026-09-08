//
//  CGSize+PixelSize.swift
//  Common
//
//  Created by 김남수 on 9/8/26.
//

import CoreGraphics

extension CGSize {
    /// 이 크기(포인트)가 화면 배율에서 차지하는 긴 변의 픽셀 수 — 다운샘플링 상한 계산용.
    public func longEdgePixelSize(scale: CGFloat) -> Int {
        Int((max(width, height) * scale).rounded(.up))
    }
}
