//
//  GroupView.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import GroupDomain
import SwiftUI
import UIComponent

/// 그룹 목록 화면 (G-001). 소속 그룹을 파르페 위 토핑으로 지그재그 배치한다.
public struct GroupView: View {
    @State private var store: GroupStore
    private let makeInviteCodeStore: () -> InviteCodeStore

    /// `YGTopBar` 높이 — 상단 바 아래에 붙는 오버레이(툴팁·드롭다운)의 기준선.
    private static let topBarHeight: CGFloat = 60
    /// 상단 바 그룹 추가 칩 높이 — 드롭다운을 칩 바로 아래에 붙이려고 쓴다.
    private static let addGroupChipHeight: CGFloat = 29
    /// 상단 바 위 여백 8 + (아이콘 버튼 44 − 칩 29) / 2.
    private static let addGroupChipTopInset: CGFloat = 15.5
    private static let addGroupMenuGap: CGFloat = 12.5
    /// 드롭다운은 칩 바로 아래에서 시작한다.
    private static var addGroupMenuTopInset: CGFloat {
        addGroupChipTopInset + addGroupChipHeight + addGroupMenuGap
    }
    private static let horizontalInset: CGFloat = 20
    /// 조회 실패 안내 문구의 y (디자인 프레임 244 − 상단 바 아래 108).
    private static let loadFailureMessageY: CGFloat = 136
    private static let overlayAnimation = Animation.snappy(duration: 0.24)

    public init(store: GroupStore, makeInviteCodeStore: @escaping () -> InviteCodeStore) {
        _store = State(initialValue: store)
        self.makeInviteCodeStore = makeInviteCodeStore
    }

    public var body: some View {
        // 딤은 상단 바 **아래** 층에 둔다 — 바를 한 번만 그리면 되고, 조작부가 딤에 묻히지 않는다.
        // 상단 바는 `ygTopBar`(VStack 쌓기) 대신 오버레이로 띄운다 — 그래야 파르페가 반투명 바 밑으로 지나간다.
        // 툴팁·드롭다운도 화면 내내 살아 있는 이 컨테이너에 둬야 나타날 때 애니메이션이 걸린다.
        ZStack(alignment: .topTrailing) {
            content
            addGroupMenuDim
            topBar
            tooltip
            addGroupMenu
        }
        .animation(Self.overlayAnimation, value: store.state.isTooltipVisible)
        .animation(Self.overlayAnimation, value: store.state.isAddGroupMenuPresented)
        .background(GridBackground())
        .navigationDestination(for: GroupRoute.self) { route in
            switch route {
            case .inviteCode: InviteCodeView(store: makeInviteCodeStore())
            }
        }
        .task { store.send(.screenAppeared) }
        .onDisappear { store.send(.screenDisappeared) }
    }

    /// 화면 위에 떠 있는 상단 바. 콘텐츠가 이 바 밑으로 스크롤된다.
    ///
    /// 바 뒤 안전영역(상태바 자리)까지 같은 톤으로 채우는 건 이 화면의 몫이다 —
    /// `YGTopBar` 는 60pt 짜리 바만 그리고 기기별 안전영역은 모른다.
    private var topBar: some View {
        YGTopBar(
            .default,
            // ponytail: 사이드 메뉴(S-10n) 미구현 — 화면 생기면 연결.
            onLeadingTap: {},
            onNewGroupTap: { store.send(.addGroupTapped) }
        )
        .background(Color.white75.ignoresSafeArea(edges: .top))
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var content: some View {
        switch store.state.phase {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let groups):
            parfaitScroll(groups: groups)
        case .failed:
            loadFailure
        }
    }

    // MARK: - 목록

    private func parfaitScroll(groups: [ParfaitGroup]) -> some View {
        scaledScroll { scale in
            ParfaitSceneView(groups: groups, scale: scale) { _ in
                // ponytail: 캔버스(C-001) 화면이 붙으면 해당 그룹으로 이동.
            }
        }
        // 툴팁은 바깥 아무 데나 눌러 닫는다 — 툴팁 자신은 위에 떠 있어 이 제스처를 가린다.
        .simultaneousGesture(
            TapGesture().onEnded { store.send(.backgroundTapped) },
            isEnabled: store.state.isTooltipVisible
        )
    }

    // MARK: - 0건 툴팁 (G-001-Empty)

    /// 상단 바 바로 아래에 고정. 꼬리가 그룹 추가 칩을 가리키므로 스크롤을 따라가지 않는다.
    @ViewBuilder
    private var tooltip: some View {
        if store.state.isTooltipVisible {
            GroupTooltipView()
                .padding(.top, Self.topBarHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // 가리키는 칩 쪽을 붙잡고 펼쳐지도록 우상단을 기준으로.
                .transition(.scale(scale: 0.94, anchor: .topTrailing).combined(with: .opacity))
        }
    }

    // MARK: - 조회 실패 (G-001-Error)

    private var loadFailure: some View {
        scaledScroll { scale in
            EmptyParfaitCupView(scale: scale)
            Text("앗, 파르페를 불러오지 못했어요.\n아래로 당겨 다시 시도해 주세요.")
                .suit(.title03SemiBold)
                .foregroundStyle(.gray500)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .offset(y: Self.loadFailureMessageY * scale)
        }
    }

    // MARK: - 공통

    /// 375pt 디자인 좌표를 화면 폭에 맞춰 확대해 그리는 스크롤 컨테이너.
    /// 스크롤 자체는 화면 최상단부터 깔리고, 콘텐츠만 상단 바 높이만큼 내려 시작한다
    /// → 처음엔 바 아래에 놓이고 스크롤하면 반투명 바 밑으로 지나간다.
    private func scaledScroll(@ViewBuilder _ scene: @escaping (CGFloat) -> some View) -> some View {
        GeometryReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    scene(proxy.size.width / ParfaitLayout.designWidth)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .contentMargins(.top, Self.topBarHeight, for: .scrollContent)
            .refreshable { await store.refresh() }
        }
    }

    // MARK: - 그룹 추가하기 드롭다운 (G-002)

    /// 본문을 덮는 딤. 상단 바보다 아래 층이라 바의 조작부는 밝게 남는다.
    @ViewBuilder
    private var addGroupMenuDim: some View {
        if store.state.isAddGroupMenuPresented {
            Color.black25
                .ignoresSafeArea()
                .onTapGesture { store.send(.addGroupMenuDismissed) }
                .transition(.opacity)
        }
    }

    /// 칩 아래 펼쳐지는 드롭다운. 딤·바보다 위 층.
    @ViewBuilder
    private var addGroupMenu: some View {
        if store.state.isAddGroupMenuPresented {
            AddGroupMenu {
                // ponytail: 그룹 만들기 화면 미구현 — 화면 생기면 연결.
                store.send(.addGroupMenuDismissed)
            }
            .padding(.top, Self.addGroupMenuTopInset)
            .padding(.trailing, Self.horizontalInset)
            // 누른 칩에서 아래로 펼쳐지도록 위쪽을 붙잡는다.
            .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Preview

@MainActor
private func previewGroupView(_ groups: [ParfaitGroup]?) -> some View {
    NavigationStack {
        GroupView(
            store: GroupStore(fetchGroupsUseCase: PreviewFetchGroupsUseCase(groups: groups)),
            makeInviteCodeStore: {
                InviteCodeStore(joinGroupUseCase: PreviewJoinGroupUseCase(joinError: nil))
            }
        )
    }
}

#Preview("목록 5건") { previewGroupView(.previewSample) }
#Preview("3건") { previewGroupView(Array([ParfaitGroup].previewSample.prefix(3))) }
#Preview("0건 — 툴팁") { previewGroupView([]) }
#Preview("조회 실패") { previewGroupView(nil) }

/// 프리뷰 전용 스텁. `groups` 가 nil 이면 조회 실패를 흉내낸다.
private struct PreviewFetchGroupsUseCase: FetchGroupsUseCase {
    let groups: [ParfaitGroup]?

    func fetchGroups() async throws -> [ParfaitGroup] {
        guard let groups else { throw CocoaError(.coderValueNotFound) }
        return groups
    }
}

private extension [ParfaitGroup] {
    static var previewSample: [ParfaitGroup] {
        let names = ["매시업", "잠탈감금", "팀와지", "helloworld", "산책애호가"]
        let nametagTypes: [NametagType] = [.type9, .type3, .type1, .type11, .type5]
        return names.indices.map { index in
            ParfaitGroup(
                id: "group-\(index)",
                name: names[index],
                thumbnailURL: nil,
                lastActivityAt: .now.addingTimeInterval(-180 * Double(index + 1)),
                createdAt: .now.addingTimeInterval(-86_400 * Double(index + 1)),
                lastActorNametagType: nametagTypes[index]
            )
        }
    }
}
