//
//  YGTopBar.swift
//  UIComponent
//
//  Created by 신상우 on 7/13/26.
//

import SwiftUI

/// 파르페 공용 상단 바.
/// 상태(Status)에 따라 좌측 버튼(사이드메뉴/뒤로가기)·중앙 콘텐츠(날짜/타이틀)·우측 액션(그룹 추가하기)이 결정된다.
/// 적용 시 시스템 내비게이션 바를 숨기고, 끊긴 스와이프 백 제스처를 복원한다.
public struct YGTopBar: View {
    public enum Status {
        /// 사이드메뉴 + 오늘 날짜
        case empty(date: Date)
        /// 사이드메뉴 + 오늘 날짜 + 그룹 추가 버튼
        case `default`(date: Date)
        /// 뒤로가기만
        case back
        /// 뒤로가기 + 타이틀
        case detail(title: String)
    }

    /// 디자인 표기가 영문 월·요일이라 로케일을 고정한다.
    private static let dateLocale = Locale(identifier: "en_US_POSIX")

    private let status: Status
    private let onLeadingTap: (() -> Void)?
    private let onNewGroupTap: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// - Parameters:
    ///   - status: 바 구성 상태.
    ///   - onLeadingTap: 좌측 버튼 탭. `empty`/`default` 은 사이드메뉴, `back`/`detail` 은 뒤로가기.
    ///     생략하면 뒤로가기(`dismiss`)가 기본 동작.
    ///   - onNewGroupTap: 그룹 추가하기 버튼 탭. `default` 에서만 노출된다.
    public init(
        _ status: Status,
        onLeadingTap: (() -> Void)? = nil,
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
                YGChip("그룹 추가하기", icon: .icPlus, placement: .leading, action: onNewGroupTap)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .padding3)   // 상하 8
        .padding(.leading, .padding3)    // 좌 8
        .padding(.trailing, .padding7)   // 우 20
        .background(barBackground)
        .toolbar(.hidden, for: .navigationBar)
        .background(SwipeBackGestureRestorer())
        // 바의 위치를 상위로 알린다 → `.ygAlert` 가 선언 순서와 무관하게 바 아래에서 알림을 내리는 데 사용.
        .anchorPreference(key: YGTopBarBoundsPreferenceKey.self, value: .bounds) { $0 }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .empty(let date), .default(let date):
            dateLabel(date)
        case .back:
            EmptyView()
        case .detail(let title):
            Text(title)
                .suit(.body01Regular)
                .foregroundStyle(.gray800)
                .padding(.leading, .gap2)
        }
    }

    /// 그룹 목록의 오늘 날짜. 예: `December 31 (Wed)`.
    private func dateLabel(_ date: Date) -> some View {
        HStack(spacing: .gap3) {
            Text(date.formatted(.dateTime.locale(Self.dateLocale).month(.wide).day()))
                .foregroundStyle(.gray800)
            Text("(\(date.formatted(.dateTime.locale(Self.dateLocale).weekday(.abbreviated))))")
                .foregroundStyle(.gray300)
        }
        .suit(.body01Regular)
    }

    /// 목록 화면은 배경 이미지 위에 얹히므로 바를 반투명 흰색으로 깔아 글자를 띄운다.
    /// 상세·뒤로가기 화면은 단색 배경이라 그대로 둔다.
    @ViewBuilder
    private var barBackground: some View {
        switch status {
        case .empty, .default: Color.white75
        case .back, .detail: Color.clear
        }
    }

    private var leadingButton: some View {
        YGIconButton(leadingIcon, size: .small, action: onLeadingTap ?? { dismiss() })
    }

    private var leadingIcon: Image {
        switch status {
        case .empty, .default: .icHamburger
        case .back, .detail: .icCaretLeft
        }
    }

    private var isDefault: Bool {
        if case .default = status { return true }
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
    ///   - onLeadingTap: 좌측 버튼 탭. `empty`/`default` 은 사이드메뉴, `back`/`detail` 은 뒤로가기.
    ///     생략하면 뒤로가기(`dismiss`)가 기본 동작.
    ///   - onNewGroupTap: 그룹 추가하기 버튼 탭. `default` 에서만 노출된다.
    func ygTopBar(
        _ status: YGTopBar.Status,
        onLeadingTap: (() -> Void)? = nil,
        onNewGroupTap: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            YGTopBar(status, onLeadingTap: onLeadingTap, onNewGroupTap: onNewGroupTap)
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
    VStack(spacing: .gap5) {
        YGTopBar(.empty(date: .now), onLeadingTap: {})
        YGTopBar(.default(date: .now), onLeadingTap: {}, onNewGroupTap: {})
        YGTopBar(.back, onLeadingTap: {})
        YGTopBar(.detail(title: "그룹이름"), onLeadingTap: {})
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.gray50)
}
