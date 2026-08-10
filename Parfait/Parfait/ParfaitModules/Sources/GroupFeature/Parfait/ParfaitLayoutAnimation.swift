//
//  ParfaitLayoutAnimation.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import SwiftUI

public extension EnvironmentValues {
    /// 그룹이 늘거나 빠질 때 토핑이 당겨지고 크림이 자라는 과정을 애니메이션으로 이을지.
    ///
    /// 기본은 켬. 디자인 확정 전까지 켠/끈 모습을 비교하려고 밖에서 끌 수 있게 열어 둔다.
    @Entry var isParfaitLayoutAnimationEnabled = true
}

public extension View {
    /// 그룹 목록의 파르페 레이아웃 애니메이션을 켜고 끈다.
    func parfaitLayoutAnimationEnabled(_ isEnabled: Bool) -> some View {
        environment(\.isParfaitLayoutAnimationEnabled, isEnabled)
    }
}
