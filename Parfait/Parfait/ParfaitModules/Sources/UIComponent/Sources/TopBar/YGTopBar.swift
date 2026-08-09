//
//  YGTopBar.swift
//  UIComponent
//
//  Created by 신상우 on 7/13/26.
//

import SwiftUI

/// 파르페 공용 상단 바.
/// 상태(Status)에 따라 좌측 버튼(사이드메뉴/뒤로가기)·중앙 콘텐츠(날짜/타이틀)·우측 액션이 결정된다.
/// 적용 시 시스템 내비게이션 바를 숨기고, 끊긴 스와이프 백 제스처를 복원한다.
public struct YGTopBar: View {
    public enum Status {
        /// 사이드메뉴 + 날짜
        case empty
        /// 사이드메뉴 + 날짜 + 그룹 추가하기 버튼
        case `default`
        /// 뒤로가기만
        case back
        /// 뒤로가기 + 타이틀
        case detail(title: String)
        /// 뒤로가기 + 타이틀 + 멤버 네임태그 칩 + 사이드메뉴
        case canvas(title: String, members: [Member])
    }

    /// `canvas` 상태 우측에 표시할 그룹 멤버.
    /// 네임태그 타입 배정·저장은 Domain 책임이라 이 컴포넌트는 받기만 한다.
    public struct Member {
        let nickname: String
        let nametagType: YGNametagChip.NametagType

        public init(nickname: String, nametagType: YGNametagChip.NametagType) {
            self.nickname = nickname
            self.nametagType = nametagType
        }
    }

    /// 멤버 칩 최대 노출 수. 초과분은 `+N` 오버플로 칩 하나로 합쳐진다.
    private static let maximumVisibleMemberCount = 5

    private let status: Status
    private let onLeadingTap: (() -> Void)?
    private let onNewGroupTap: (() -> Void)?
    private let onTrailingTap: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// - Parameters:
    ///   - status: 바 구성 상태.
    ///   - onLeadingTap: 좌측 버튼 탭. `empty`/`default` 은 사이드메뉴, `back`/`detail`/`canvas` 는 뒤로가기.
    ///     생략하면 뒤로가기(`dismiss`)가 기본 동작.
    ///   - onNewGroupTap: 그룹 추가하기 버튼 탭. `default` 에서만 노출된다.
    ///   - onTrailingTap: 우측 사이드메뉴 버튼 탭. `canvas` 에서만 노출된다.
    public init(
        _ status: Status,
        onLeadingTap: (() -> Void)? = nil,
        onNewGroupTap: (() -> Void)? = nil,
        onTrailingTap: (() -> Void)? = nil
    ) {
        self.status = status
        self.onLeadingTap = onLeadingTap
        self.onNewGroupTap = onNewGroupTap
        self.onTrailingTap = onTrailingTap
    }

    public var body: some View {
        HStack(spacing: 0) {
            leadingButton

            content

            Spacer(minLength: 0)

            trailing
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .padding3)   // 상하 8
        .padding(.leading, .padding3)    // 좌 8
        .padding(.trailing, isCanvas ? .padding3 : .padding7)   // 우 8(canvas) / 20
        .background(barBackgroundColor)
        .toolbar(.hidden, for: .navigationBar)
        .background(SwipeBackGestureRestorer())
        // 바의 위치를 상위로 알린다 → `.ygAlert` 가 선언 순서와 무관하게 바 아래에서 알림을 내리는 데 사용.
        .anchorPreference(key: YGTopBarBoundsPreferenceKey.self, value: .bounds) { $0 }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .empty, .default:
            dateView
        case .back:
            EmptyView()
        case .detail(let title), .canvas(let title, _):
            Text(title)
                .suit(.body01Regular)
                .foregroundStyle(.gray800)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch status {
        case .default:
            if let onNewGroupTap {
                YGChip("그룹 추가하기", icon: .icPlus, placement: .leading, action: onNewGroupTap)
            }
        case .canvas(_, let members):
            memberChips(members)
            YGIconButton(.icHamburger, size: .small, action: onTrailingTap ?? {})
        case .empty, .back, .detail:
            EmptyView()
        }
    }

    private var leadingButton: some View {
        YGIconButton(leadingIcon, size: .small, action: onLeadingTap ?? { dismiss() })
    }

    private var leadingIcon: Image {
        switch status {
        case .empty, .default: .icHamburger
        case .back, .detail, .canvas: .icCaretLeft
        }
    }

    /// `December 31 (Wed)` — 날짜는 gray800, 요일은 gray300.
    private var dateView: some View {
        let now = Date.now
        let locale = Locale(identifier: "en_US")

        return HStack(spacing: .gap3) {
            Text(now.formatted(.dateTime.month(.wide).day().locale(locale)))
                .suit(.body01Regular)
                .foregroundStyle(.gray800)
            Text("(\(now.formatted(.dateTime.weekday(.abbreviated).locale(locale))))")
                .suit(.body01Regular)
                .foregroundStyle(.gray300)
        }
    }

    /// 멤버 네임태그 칩 목록. 12 겹침 — 먼저 그려지는 왼쪽 칩이 아래에 깔린다 (HStack 기본 z-순서).
    /// 최대 5개 노출, 6개 이상이면 5개 + 초과 인원 `+N` 칩.
    private func memberChips(_ members: [Member]) -> some View {
        let visibleMembers = members.prefix(Self.maximumVisibleMemberCount)
        let overflowCount = members.count - Self.maximumVisibleMemberCount

        return HStack(spacing: -.gap4) {
            ForEach(Array(visibleMembers.enumerated()), id: \.offset) { _, member in
                YGNametagChip(nickname: member.nickname, type: member.nametagType, size: .medium)
            }
            if overflowCount > 0 {
                YGNametagChip(overflowCount: overflowCount)
            }
        }
    }

    private var barBackgroundColor: Color {
        switch status {
        case .empty, .default: return .white75
        case .back, .detail, .canvas: return .clear
        }
    }

    private var isCanvas: Bool {
        if case .canvas = status { return true }
        return false
    }
}

/// `YGTopBar` 의 bounds 를 상위 뷰로 전달하는 프리퍼런스.
/// `.ygAlert` 가 같은 화면 계층의 바를 찾아 그 아래에서 알림을 내리는 데 쓴다.
struct YGTopBarBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
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
    ///   - onLeadingTap: 좌측 버튼 탭. `empty`/`default` 은 사이드메뉴, `back`/`detail`/`canvas` 는 뒤로가기.
    ///     생략하면 뒤로가기(`dismiss`)가 기본 동작.
    ///   - onNewGroupTap: 그룹 추가하기 버튼 탭. `default` 에서만 노출된다.
    ///   - onTrailingTap: 우측 사이드메뉴 버튼 탭. `canvas` 에서만 노출된다.
    func ygTopBar(
        _ status: YGTopBar.Status,
        onLeadingTap: (() -> Void)? = nil,
        onNewGroupTap: (() -> Void)? = nil,
        onTrailingTap: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            YGTopBar(
                status,
                onLeadingTap: onLeadingTap,
                onNewGroupTap: onNewGroupTap,
                onTrailingTap: onTrailingTap
            )
            self
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// 시스템 내비게이션 바를 숨기면 `interactivePopGestureRecognizer` 의 delegate 가 동작을 막아
/// 스와이프 백이 끊긴다. 화면에 나타날 때마다 delegate 를 재지정해 제스처를 복원한다.
private struct SwipeBackGestureRestorer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> RestorerViewController {
        RestorerViewController()
    }

    func updateUIViewController(_ viewController: RestorerViewController, context: Context) {}

    final class RestorerViewController: UIViewController, UIGestureRecognizerDelegate {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // 루트 화면에서 제스처가 시작되면 내비게이션이 멈추는 문제 방지
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

#Preview {
    let members: [YGTopBar.Member] = [
        .init(nickname: "김남수", nametagType: .type5),
        .init(nickname: "김서연", nametagType: .type4),
        .init(nickname: "김상우", nametagType: .type3),
        .init(nickname: "김파르", nametagType: .type2),
        .init(nickname: "김페야", nametagType: .type12),
        .init(nickname: "여섯째", nametagType: .type1),
        .init(nickname: "일곱째", nametagType: .type6)
    ]

    VStack(spacing: .gap5) {
        YGTopBar(.empty, onLeadingTap: {})
        YGTopBar(.default, onLeadingTap: {}, onNewGroupTap: {})
        YGTopBar(.back, onLeadingTap: {})
        YGTopBar(.detail(title: "그룹이름"), onLeadingTap: {})
        YGTopBar(
            .canvas(title: "그룹이름", members: members),
            onLeadingTap: {},
            onTrailingTap: {}
        )
        YGTopBar(
            .canvas(title: "그룹이름", members: Array(members.prefix(3))),
            onLeadingTap: {},
            onTrailingTap: {}
        )
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.gray50)
}
