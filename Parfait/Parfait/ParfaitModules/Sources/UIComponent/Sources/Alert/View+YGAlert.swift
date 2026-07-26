//
//  View+YGAlert.swift
//  UIComponent
//
//  Created by 신상우 on 7/17/26.
//

import SwiftUI

public extension View {
    /// 알림 배너를 위에서 내려오는 토스트로 띄운다.
    ///
    /// Figma 노출·닫기 정책(805-4997):
    /// 위에서 아래로 내려와 노출되고, ① 터치로 아래에서 위로 올리거나 ② 2.5초가 지나면 닫힌다.
    ///
    /// 적용한 뷰 계층 안에 `YGTopBar` 가 있으면 알림은 **항상 그 바 아래 레이어**에서 내려온다
    /// (`ygTopBar` 안쪽/바깥쪽 어느 순서로 선언해도 동일). 바가 없으면 뷰의 상단 경계에서 내려온다.
    ///
    /// ```swift
    /// ScrollView { ... }
    ///     .ygTopBar(.default, onLeadingTap: { ... })
    ///     .ygAlert(isPresented: $isPresented) {
    ///         YGAlert(title: "제로", subtitle: "메모지를 남겼어요")
    ///     }
    /// ```
    func ygAlert(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        modifier(YGAlertPresentationModifier(
            item: Binding<Bool?>(
                get: { isPresented.wrappedValue ? true : nil },
                set: { isPresented.wrappedValue = $0 ?? false }
            ),
            alertContent: { _ in content() }
        ))
    }

    /// 아이템 기반 프레젠테이션. 표시 중 아이템이 **바뀌면 내용이 교체되고 2.5초 타이머가 처음부터 다시 시작**된다.
    ///
    /// 같은 값을 다시 넣으면 변화로 보지 않는다 — 재탭에도 매번 갱신하려면 아이템에 고유 id 를 포함할 것.
    func ygAlert<Item: Equatable>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View {
        modifier(YGAlertPresentationModifier(item: item, alertContent: content))
    }
}

private struct YGAlertPresentationModifier<Item: Equatable, AlertContent: View>: ViewModifier {
    @Binding var item: Item?
    @ViewBuilder let alertContent: (Item) -> AlertContent

    /// 닫기 정책 ②: 2.5초 경과 시 자동 닫힘. 아이템이 바뀌면 처음부터 다시 센다.
    private let autoDismissDelay: Duration = .seconds(2.5)
    /// 닫기 정책 ①: 위로 이 거리보다 크게 스와이프하면 닫힘
    private let dismissDragThreshold: CGFloat = 20

    @State private var dragOffset: CGFloat = 0
    /// 실측 전에도 화면 밖에 숨도록 넉넉한 초기값 (`onGeometryChange` 로 갱신)
    @State private var alertHeight: CGFloat = 300
    /// 퇴장 슬라이드 동안에도 마지막 내용을 그리기 위해 보관 (한 번 뜨면 유지)
    @State private var lastRenderedItem: Item?

    private var isPresented: Bool { item != nil }

    func body(content: Content) -> some View {
        // 계층 안의 YGTopBar 위치(anchor)를 읽어, 선언 순서와 무관하게 바 아래에서 알림을 내린다.
        content.overlayPreferenceValue(YGTopBarBoundsPreferenceKey.self) { topBarBounds in
            GeometryReader { proxy in
                alertLayer(topInset: topBarBounds.map { proxy[$0].maxY } ?? 0)
            }
        }
    }

    // 알림을 (최초 등장 이후) 항상 레이아웃에 두고 offset 만 움직인다.
    // if + transition 으로 넣었다 뺐다 하면 클립 영역과 상호작용해 슬라이드가 어색해짐.
    private func alertLayer(topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if let renderedItem = item ?? lastRenderedItem {
                alertContent(renderedItem)
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { alertHeight = $0 }
                    .gesture(dismissDrag)
                    .offset(y: isPresented ? dragOffset : -alertHeight)
                    .allowsHitTesting(isPresented)
                    .accessibilityHidden(!isPresented)
                    .transition(.move(edge: .top)) // 최초 1회 등장에만 발동 — 이후엔 offset 이 움직인다
            }
        }
        // 클립 영역(너비·높이)을 알림 유무와 무관하게 고정.
        // 비어 있을 때 크기가 0이면 최초 등장 시 컨테이너가 '커지면서' 내려오는 것처럼 보인다.
        .frame(maxWidth: .infinity, minHeight: alertHeight, maxHeight: alertHeight, alignment: .top)
        .clipped() // 자리 밖은 가림 → 위 레이어(탑바) 뒤에서 내려오는 모션
        .padding(.top, topInset) // YGTopBar 가 같은 계층에 있으면 그 바로 아래부터 시작
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(duration: 0.35), value: isPresented)
        .task(id: item) { await autoDismiss() }
        .onChange(of: item) { _, newItem in
            if let newItem {
                lastRenderedItem = newItem
                dragOffset = 0
            }
        }
    }

    /// 위로만 끌리고, 임계값을 넘겨 놓으면 닫힌다.
    private var dismissDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = min(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height < -dismissDragThreshold {
                    item = nil
                } else {
                    withAnimation(.spring(duration: 0.25)) { dragOffset = 0 }
                }
            }
    }

    private func autoDismiss() async {
        guard item != nil else { return }
        try? await Task.sleep(for: autoDismissDelay)
        guard !Task.isCancelled else { return }
        item = nil
    }
}
