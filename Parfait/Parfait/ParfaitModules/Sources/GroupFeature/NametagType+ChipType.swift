//
//  NametagType+ChipType.swift
//  GroupFeature
//
//  Created by 신상우 on 8/10/26.
//

import GroupDomain
import UIComponent

extension GroupDomain.NametagType {
    /// Domain 의 타입 번호를 UI 컴포넌트의 타입으로 옮긴다. 같은 1~12 번호 체계다.
    var chipType: YGNametagChip.NametagType {
        YGNametagChip.NametagType(rawValue: rawValue) ?? .type1
    }
}
