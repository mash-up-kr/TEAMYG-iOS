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

    /// 상단 바 그룹 추가 칩 높이 — 드롭다운을 칩 바로 아래에 붙이려고 쓴다.
    private static let addGroupChipHeight: CGFloat = 29
    /// 상단 바 위 여백 8 + (아이콘 버튼 44 − 칩 29) / 2.
    private static let addGroupChipTopInset: CGFloat = 15.5
    private static let addGroupMenuGap: CGFloat = 12.5
    private static let horizontalInset: CGFloat = 20
    /// 조회 실패 안내 문구의 y (디자인 프레임 244 − 상단 바 아래 108).
    private static let loadFailureMessageY: CGFloat = 136

    public init(store: GroupStore, makeInviteCodeStore: @escaping () -> InviteCodeStore) {
        _store = State(initialValue: store)
        self.makeInviteCodeStore = makeInviteCodeStore
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .ygTopBar(
                    .default,
                    // ponytail: 사이드 메뉴(S-10n) 미구현 — 화면 생기면 연결.
                    onLeadingTap: {},
                    onNewGroupTap: { store.send(.addGroupTapped) }
                )

            if store.state.isAddGroupMenuPresented {
                addGroupMenuOverlay
            }
        }
        .background(.whiteFixed)
        .navigationDestination(for: GroupRoute.self) { route in
            switch route {
            case .inviteCode: InviteCodeView(store: makeInviteCodeStore())
            }
        }
        .task { store.send(.screenAppeared) }
        .onDisappear { store.send(.screenDisappeared) }
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

    private func parfaitScroll(groups: [GroupDomain.Group]) -> some View {
        scaledScroll { scale in
            ParfaitSceneView(groups: groups, scale: scale) { _ in
                // ponytail: 캔버스(C-001) 화면이 붙으면 해당 그룹으로 이동.
            }
            dateHeader
            if store.state.isTooltipVisible {
                GroupTooltipView()
                    .padding(.horizontal, Self.horizontalInset)
            }
        }
        // 툴팁은 바깥 아무 데나 눌러 닫는다 — 툴팁 자신은 위에 있어 이 제스처를 가린다.
        .simultaneousGesture(
            TapGesture().onEnded { store.send(.backgroundTapped) },
            isEnabled: store.state.isTooltipVisible
        )
    }

    // MARK: - 조회 실패 (G-001-Error)

    private var loadFailure: some View {
        scaledScroll { scale in
            EmptyParfaitCupView(scale: scale)
            dateHeader
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
    private func scaledScroll(@ViewBuilder _ scene: @escaping (CGFloat) -> some View) -> some View {
        GeometryReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    scene(proxy.size.width / ParfaitLayout.designWidth)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .refreshable { await store.refresh() }
        }
    }

    private var dateHeader: some View {
        GroupDateHeader(date: .now)
            .padding(.leading, Self.horizontalInset)
    }

    // MARK: - 그룹 추가하기 드롭다운 (G-002)

    private var addGroupMenuOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.black25
                .ignoresSafeArea()
                .onTapGesture { store.send(.addGroupMenuDismissed) }

            // 딤 위에 칩을 다시 그려 누른 버튼만 밝게 남긴다.
            VStack(alignment: .trailing, spacing: Self.addGroupMenuGap) {
                YGChip("새 그룹", icon: .icPlus, placement: .leading) {
                    store.send(.addGroupMenuDismissed)
                }
                .frame(height: Self.addGroupChipHeight)

                AddGroupMenu {
                    // ponytail: 그룹 만들기 화면 미구현 — 화면 생기면 연결.
                    store.send(.addGroupMenuDismissed)
                }
            }
            .padding(.top, Self.addGroupChipTopInset)
            .padding(.trailing, Self.horizontalInset)
        }
    }
}

// MARK: - Preview

@MainActor
private func previewGroupView(_ groups: [GroupDomain.Group]?) -> some View {
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
#Preview("3건") { previewGroupView(Array([GroupDomain.Group].previewSample.prefix(3))) }
#Preview("0건 — 툴팁") { previewGroupView([]) }
#Preview("조회 실패") { previewGroupView(nil) }

/// 프리뷰 전용 스텁. `groups` 가 nil 이면 조회 실패를 흉내낸다.
private struct PreviewFetchGroupsUseCase: FetchGroupsUseCase {
    let groups: [GroupDomain.Group]?

    func fetchGroups() async throws -> [GroupDomain.Group] {
        guard let groups else { throw CocoaError(.coderValueNotFound) }
        return groups
    }
}

private extension [GroupDomain.Group] {
    static var previewSample: [GroupDomain.Group] {
        let names = ["매시업", "잠탈감금", "팀와지", "helloworld", "산책애호가"]
        let nametagTypes: [NametagType] = [.type9, .type3, .type1, .type11, .type5]
        return names.indices.map { index in
            GroupDomain.Group(
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
