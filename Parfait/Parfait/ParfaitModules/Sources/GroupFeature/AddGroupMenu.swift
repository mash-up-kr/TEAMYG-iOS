//
//  AddGroupMenu.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import SwiftUI
import UIComponent

/// "그룹 추가하기" 칩을 눌렀을 때 그 아래 펼쳐지는 드롭다운 (G-002).
struct AddGroupMenu: View {
    var body: some View {
        // 두 화면 모두 그룹 피처 안쪽 라우트라 값 기반 링크로 바로 건다.
        VStack(spacing: 0) {
            menuLink(.createGroup, icon: .icNewgroup, title: "그룹 만들기")

            Rectangle()
                .fill(.black5)
                .frame(height: 1)
                .padding(.horizontal, .padding6)

            menuLink(.inviteCode, icon: .icEnter, title: "그룹 들어가기")
        }
        .frame(width: 136)
        .background(.whiteFixed, in: .rect(cornerRadius: Radius.medium1))
    }

    private func menuLink(_ route: GroupRoute, icon: Image, title: String) -> some View {
        NavigationLink(value: route) {
            AddGroupMenuRowLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }
}

/// 드롭다운 한 줄. `YGActionItem` 과 여백·색은 같지만 아이콘 슬롯이 있어 여기서 따로 그린다.
/// ponytail: UIComponent 의 `YGActionItem` 에 아이콘 변형이 생기면 그걸로 교체.
private struct AddGroupMenuRowLabel: View {
    let icon: Image
    let title: String

    var body: some View {
        HStack(spacing: .gap2) {
            icon
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
            Text(title)
                .suit(.body02Regular)
                .lineLimit(1)
        }
        .foregroundStyle(.gray500)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .padding5)
        .padding(.horizontal, .padding6)
        .contentShape(.rect)
    }
}

#Preview {
    NavigationStack {
        AddGroupMenu()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 20)
            .background(.black25)
    }
}
