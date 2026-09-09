//
//  ToppingBorderStyle.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 토핑 테두리. 이미지에 굽지 않고 값으로 저장했다가 표시할 때 렌더한다.
/// `width` 는 화면에 그려질 절대 두께(pt)다 (`2~50`).
public enum ToppingBorderStyle: Equatable, Sendable {
    case none
    case solid(colorHex: String, width: Double)

    public static let widthRange: ClosedRange<Double> = 2...30
}
