//
//  CGImage+ByteCount.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/27/26.
//

import CoreGraphics

extension CGImage {
    /// 비트맵이 실제로 차지하는 바이트. 이미지 캐시의 비용 단위로 쓴다 —
    /// 장수로 세면 큰 토핑 몇 장에 메모리가 쏠려도 상한에 걸리지 않는다.
    var byteCount: Int {
        height * bytesPerRow
    }
}
