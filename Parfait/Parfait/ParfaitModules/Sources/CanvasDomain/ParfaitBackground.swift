//
//  ParfaitBackground.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

import Foundation

/// 캔버스 배경. 설정하지 않은 캔버스는 배경 자체가 없다(`nil`).
public enum ParfaitBackground: Equatable, Sendable {
    case color(hex: String)
    case image(url: URL)
}

/// 배경 변경 요청 값. 이미지 배경은 업로드가 끝난 `imageID` 로 지정한다.
public enum ParfaitBackgroundChange: Equatable, Sendable {
    case color(hex: String)
    case image(imageID: Int)
}
