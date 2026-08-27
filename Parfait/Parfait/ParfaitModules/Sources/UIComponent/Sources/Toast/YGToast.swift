//
//  YGToast.swift
//  UIComponent
//
//  Created by 신상우 on 7/29/26.
//

import SwiftUI

/// 파르페 토스트 바 컴포넌트.
///
/// Figma `Toast` 컴포넌트 세트(144-5222)의 한 줄 메시지 바.
/// 노출·닫기·스택 정책(위에서 내려옴 · 스와이프 업/2초 닫힘 · Z축 쌓임)은
/// ``SwiftUICore/View/ygToastOverlay(_:)`` 가 담당하고, 이 뷰는 바 모양만 그린다.
public struct YGToast: View {
    /// Figma `Type` variant — Alert / Warning / Error / Success
    public enum Kind: Equatable {
        /// 유저 행동 알림. 강조된 유저명 뒤에 본문이 이어진다 (예: "닉네임" + "님이 59분 전에 쌓았어요").
        /// Figma 실측상 유저명·본문 사이 간격은 0 — 띄어쓰기가 필요하면 본문에 포함한다.
        ///
        /// 유저명 색은 정책상 유저의 Nametag 타입에 **강제 매핑**되므로 색을 직접 받지 않고
        /// `nametagType` 을 받아 ``YGNametagChip/NametagType/toastNicknameColor`` 로 파생한다.
        case alert(username: String, nametagType: YGNametagChip.NametagType)
        case normal
        case warning
        case error
        case success
    }

    private let kind: Kind
    private let message: String

    public init(_ kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 0) {
            switch kind {
            case .alert(let username, let nametagType):
                Text(username)
                    .suit(.body02SemiBold)
                    .foregroundStyle(nametagType.toastNicknameColor)
                Text(message)
                    .suit(.body02Regular)
                    .foregroundStyle(.gray100)
            case .normal:
                Text(message)
                    .suit(.body02Regular)
                    .foregroundStyle(.gray100)
            case .warning:
                Text(message)
                    .suit(.body02SemiBold)
                    .foregroundStyle(.pudding600)
            case .error:
                Text(message)
                    .suit(.body02SemiBold)
                    .foregroundStyle(.cherry500)
            case .success:
                Text(message)
                    .suit(.body02SemiBold)
                    .foregroundStyle(.melon600)
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .padding5)
        .padding(.horizontal, .padding6)
        // ignoresSafeAreaEdges 기본값(.all)이면 화면 상단에 붙었을 때 배경이
        // 상태 바·내비 바 영역까지 번져 바 높이가 무너진다
        .background(.black75, ignoresSafeAreaEdges: [])
    }
}

#Preview("타입") {
    VStack(spacing: .gap5) {
        YGToast(.alert(username: "WWWWWWWWWW", nametagType: .type11), message: "님이 59분 전에 쌓았어요")
        YGToast(.normal, message: "알 수 없음 님이 오래 전에 쌓았어요")
        YGToast(.warning, message: "내 토핑만 편집할 수 있어요")
        YGToast(.error, message: "갤러리 저장에 실패했어요. 나중에 다시 시도해 주세요.")
        YGToast(.success, message: "초대 코드를 복사했어요")
    }
    .background(.whiteFixed)
}

#Preview("닉네임 컬러 매핑") {
    VStack(spacing: .gap1) {
        ForEach(YGNametagChip.NametagType.allCases, id: \.rawValue) { nametagType in
            YGToast(
                .alert(username: "닉네임", nametagType: nametagType),
                message: "님이 방금 쌓았어요 (Type \(nametagType.rawValue))"
            )
        }
    }
    .background(.whiteFixed)
}
