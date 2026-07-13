//
//  YGTopBar.swift
//  UIComponent
//
//  Created by 신상우 on 7/13/26.
//

import SwiftUI

/// 파르페 공용 상단 바.
/// 상태(Status)에 따라 좌측 버튼(사이드메뉴/뒤로가기)·중앙 콘텐츠(로고/타이틀)·우측 액션(새 그룹)이 결정된다.
public struct YGTopBar: View {
    public enum Status {
        /// 사이드메뉴 + 로고
        case empty
        /// 사이드메뉴 + 로고 + 새 그룹 버튼
        case `default`
        /// 뒤로가기만
        case back
        /// 뒤로가기 + 타이틀
        case detail(title: String)
    }

    private let status: Status
    private let onLeadingTap: () -> Void
    private let onNewGroupTap: (() -> Void)?

    /// - Parameters:
    ///   - status: 바 구성 상태.
    ///   - onLeadingTap: 좌측 버튼 탭. `empty`/`default` 은 사이드메뉴, `back`/`detail` 은 뒤로가기.
    ///   - onNewGroupTap: 새 그룹 버튼 탭. `default` 에서만 노출된다.
    public init(
        _ status: Status,
        onLeadingTap: @escaping () -> Void,
        onNewGroupTap: (() -> Void)? = nil
    ) {
        self.status = status
        self.onLeadingTap = onLeadingTap
        self.onNewGroupTap = onNewGroupTap
    }

    public var body: some View {
        HStack(spacing: 0) {
            leadingButton

            content

            Spacer(minLength: 0)

            if isDefault, let onNewGroupTap {
                newGroupButton(action: onNewGroupTap)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .padding3)   // 상하 8
        .padding(.leading, .padding3)    // 좌 8
        .padding(.trailing, .padding7)   // 우 20
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .empty, .default:
            logo
        case .back:
            EmptyView()
        case .detail(let title):
            Text(title)
                .suit(.body01Regular)
                .foregroundStyle(.gray800)
                .padding(.leading, .gap2)
        }
    }

    private var leadingButton: some View {
        Button(action: onLeadingTap) {
            leadingIcon
                .resizable()
                .frame(width: 24, height: 24)
                .padding(10)
                .foregroundStyle(.gray900)
        }
    }

    private var leadingIcon: Image {
        switch status {
        case .empty, .default: .icHamburger
        case .back, .detail: .icCaretLeft
        }
    }

    // TODO: 로고 에셋 확정 시 Image 로 교체 (현재 앱명 워드마크 임시 플레이스홀더)
    private var logo: some View {
        Text("Parfait")
            .suit(.title03Bold)
            .foregroundStyle(.gray900)
            .padding(.leading, .gap2)
    }

    private func newGroupButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: .gap2) {           // + 와 새 그룹 사이 4
                Image.icPlus
                    .resizable()
                    .frame(width: 16, height: 16)
                Text("새 그룹")
                    .suit(.body02Regular)
            }
            .foregroundStyle(.gray600)         // 새 그룹 텍스트·+ 아이콘 동일 색
            .padding(.vertical, .padding2)     // 위아래 4
            .padding(.leading, .padding3)      // 좌 8
            .padding(.trailing, .padding5)     // 우 12
            .background(.cherry50, in: .capsule)
        }
    }

    private var isDefault: Bool {
        if case .default = status { return true }
        return false
    }
}

public extension View {
    /// 이 뷰 위에 `YGTopBar` 를 얹어 하나의 화면 구조로 만든다.
    /// `VStack(spacing: 0) { YGTopBar(...); content }` 래핑을 대신하므로 호출부에서 직접 감쌀 필요가 없다.
    ///
    /// ```swift
    /// ScrollView { ... }
    ///     .ygTopBar(.detail(title: "그룹이름"), onLeadingTap: { router.pop() })
    /// ```
    ///
    /// - Parameters:
    ///   - status: 바 구성 상태.
    ///   - onLeadingTap: 좌측 버튼 탭. `empty`/`default` 은 사이드메뉴, `back`/`detail` 은 뒤로가기.
    ///   - onNewGroupTap: 새 그룹 버튼 탭. `default` 에서만 노출된다.
    func ygTopBar(
        _ status: YGTopBar.Status,
        onLeadingTap: @escaping () -> Void,
        onNewGroupTap: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            YGTopBar(status, onLeadingTap: onLeadingTap, onNewGroupTap: onNewGroupTap)
            self
        }
    }
}

#Preview {
    VStack(spacing: .gap5) {
        YGTopBar(.empty, onLeadingTap: {})
        YGTopBar(.default, onLeadingTap: {}, onNewGroupTap: {})
        YGTopBar(.back, onLeadingTap: {})
        YGTopBar(.detail(title: "그룹이름"), onLeadingTap: {})
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.gray50)
}
