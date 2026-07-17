//
//  YGNametagChip.swift
//  UIComponent
//
//  Created by 신상우 on 7/15/26.
//

import SwiftUI

/// 파르페 네임태그 칩 컴포넌트.
///
/// 닉네임 첫 글자가 들어간 원형 프로필 칩. Figma `Nametag-Chip` 컴포넌트셋으로,
/// 타입(1~12)별 배경·보더·글자 색이 정해져 있고 사이즈는 medium(28) / large(40) 두 가지다.
/// 타입은 계정 생성 시 1회 랜덤 배정되어 이후 변하지 않으며, 배정·저장은 Domain 책임이라
/// 이 컴포넌트는 `type` 을 받기만 한다.
///
/// 남는 인원 수를 표시하는 오버플로 변형(`+N`)은 `init(overflowCount:)` 로 만든다.
public struct YGNametagChip: View {
    /// Nametag 타입 (1~12). 6개 컬러(연핑크·진핑크·체리·그레이·멜론·푸딩) × 2타입.
    public enum NametagType: Int, CaseIterable {
        case type1 = 1
        case type2
        case type3
        case type4
        case type5
        case type6
        case type7
        case type8
        case type9
        case type10
        case type11
        case type12

        /// 토스트 알림 닉네임 텍스트에 강제 매핑되는 강조색 (정책 문서 기준).
        /// `YGGrouptagChip` 의 Timestamp 는 이보다 한 단계 낮은 색을 쓴다 (디자이너 확정) —
        /// 해당 매핑은 `YGGrouptagChip` 내부에 있다.
        public var toastNicknameColor: Color {
            switch self {
            case .type1, .type2: return .cherry200
            case .type3, .type4: return .cherry300
            case .type5, .type6: return .cherry400
            case .type7, .type8: return .whiteFixed
            case .type9, .type10: return .melon500
            case .type11, .type12: return .pudding500
            }
        }
    }

    /// 칩 사이즈 — `.medium`(28) / `.large`(40)
    public enum Size {
        case medium
        case large

        var diameter: CGFloat {
            switch self {
            case .medium: return 28
            case .large: return 40
            }
        }

        var borderWidth: CGFloat {
            switch self {
            case .medium: return 0.75
            case .large: return 1
            }
        }

        var typography: Typography {
            switch self {
            case .medium: return .caption01Regular
            case .large: return .body01Regular
            }
        }
    }

    private enum Content {
        case initial(String, NametagType)
        case overflow(Int)
    }

    private let content: Content
    private let size: Size

    /// 닉네임 첫 글자 칩. `nickname` 전체를 넘기면 첫 글자만 표시한다.
    public init(nickname: String, type: NametagType, size: Size) {
        self.content = .initial(nickname.first.map(String.init) ?? "", type)
        self.size = size
    }

    /// 오버플로 칩 (`+N`). Figma 상 medium 사이즈만 존재한다.
    public init(overflowCount: Int) {
        self.content = .overflow(overflowCount)
        self.size = .medium
    }

    public var body: some View {
        Text(text)
            .suit(size.typography)
            .lineLimit(1)
            .foregroundStyle(textColor)
            .frame(width: size.diameter, height: size.diameter)
            .background(backgroundColor, in: .circle)
            .overlay {
                Circle().strokeBorder(borderColor, lineWidth: size.borderWidth)
            }
    }

    private var text: String {
        switch content {
        case .initial(let initial, _): return initial
        case .overflow(let count): return "+\(count)"
        }
    }

    private var backgroundColor: Color {
        switch content {
        case .initial(_, let type): return type.backgroundColor
        case .overflow: return .whiteFixed
        }
    }

    private var borderColor: Color {
        switch content {
        case .initial(_, let type): return type.borderColor
        case .overflow: return .gray100
        }
    }

    private var textColor: Color {
        switch content {
        case .initial(_, let type): return type.initialColor
        case .overflow: return .gray900
        }
    }
}

// MARK: - 타입별 색상

private extension YGNametagChip.NametagType {
    var backgroundColor: Color {
        switch self {
        case .type1: return .cherry100
        case .type2: return .cherry200
        case .type3: return .cherry400
        case .type4: return .cherry300
        case .type5: return .cherry500
        case .type6: return .cherry700
        case .type7: return .whiteFixed
        case .type8: return .gray200
        case .type9, .type10: return .melon500
        case .type11, .type12: return .pudding500
        }
    }

    var borderColor: Color {
        switch self {
        case .type1, .type4, .type9: return .cherry50
        case .type2, .type3, .type5, .type10, .type12: return .cherry100
        case .type6, .type7, .type8: return .cherry200
        case .type11: return .melon500
        }
    }

    var initialColor: Color {
        switch self {
        case .type1, .type10, .type11, .type12: return .cherry300
        case .type2, .type3, .type7: return .melon500
        case .type4, .type8, .type9: return .pudding500
        case .type5: return .cherry100
        case .type6: return .whiteFixed
        }
    }
}

#Preview {
    Grid(horizontalSpacing: .gap3, verticalSpacing: .gap3) {
        GridRow {
            ForEach(YGNametagChip.NametagType.allCases, id: \.rawValue) { type in
                YGNametagChip(nickname: "김남수", type: type, size: .medium)
            }
            YGNametagChip(overflowCount: 7)
        }
        GridRow {
            ForEach(YGNametagChip.NametagType.allCases, id: \.rawValue) { type in
                YGNametagChip(nickname: "김남수", type: type, size: .large)
            }
        }
    }
    .padding()
}
