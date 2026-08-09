//
//  GroupListDemoView.swift
//  Parfait
//
//  Created by 신상우 on 8/1/26.
//

#if DEBUG
import GroupDomain
import GroupFeature
import SwiftUI
import UIComponent

/// 그룹 목록(G-001) 데모 진입점. 서버 없이 배치 규칙을 눈으로 확인하려고 두는 개발 전용 화면이다.
///
/// 패널 값이 바뀌면 화면을 다시 만들지 않고 `GroupStore` 에 새로고침만 시킨다 —
/// 뷰를 새로 만들면 로딩 단계를 거치며 화면이 한 번 비어 깜빡이기 때문이다.
struct GroupListDemoView: View {
    let dependencies: AppDependencies

    /// 패널이 직접 쓰는 값. 저장소가 읽어 가는 사본은 `demoState` 안에 따로 둔다.
    @State private var knobs = DemoKnobs()
    @State private var isPanelExpanded = false
    /// 데이터와 무관해 새로고침이 필요 없으므로 `DemoKnobs` 와 분리해 둔다.
    @State private var isLayoutAnimationEnabled = true
    @State private var store: GroupStore
    /// 저장소가 붙들고 있는 것과 같은 인스턴스여야 한다 — `let` 으로 두면 뷰가 다시 만들어질 때마다
    /// 새 상자가 생겨 패널 조작이 저장소에 안 닿는다.
    @State private var demoState: DemoGroupState

    @MainActor
    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let demoState = DemoGroupState()
        _demoState = State(initialValue: demoState)
        _store = State(
            initialValue: GroupStore(
                fetchGroupsUseCase: FetchGroupsUseCaseImpl(
                    groupRepository: DemoGroupRepository(demoState: demoState)
                )
            )
        )
    }

    var body: some View {
        GroupView(store: store, makeInviteCodeStore: dependencies.makeInviteCodeStore)
            .parfaitLayoutAnimationEnabled(isLayoutAnimationEnabled)
            .overlay(alignment: .bottomTrailing) { panel }
            .onChange(of: knobs) { _, newKnobs in
                demoState.knobs = newKnobs
                Task { await store.refresh() }
            }
    }

    // MARK: - 플로팅 패널

    private var panel: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isPanelExpanded {
                controls
            }
            expandButton
        }
        .padding(16)
    }

    private var expandButton: some View {
        Button {
            withAnimation(.snappy) { isPanelExpanded.toggle() }
        } label: {
            Image(systemName: isPanelExpanded ? "xmark" : "slider.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.75), in: .circle)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepper
            checkRow("배치 애니메이션", isOn: isLayoutAnimationEnabled) {
                isLayoutAnimationEnabled.toggle()
            }
            checkRow("새로고침마다 최근 활동 갱신", isOn: knobs.bumpsActivityOnRefresh) {
                knobs.bumpsActivityOnRefresh.toggle()
            }
            checkRow("목록 조회 실패", isOn: knobs.isLoadFailing) { knobs.isLoadFailing.toggle() }
            checkRow("토핑 이미지 로드 실패", isOn: knobs.isToppingImageFailing) {
                knobs.isToppingImageFailing.toggle()
            }
            refreshButton
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: 240)
        .background(.black.opacity(0.8), in: .rect(cornerRadius: 14))
    }

    private var stepper: some View {
        HStack {
            Text("그룹 \(knobs.groupCount)건")
            Spacer()
            countButton("−") { knobs.groupCount = max(0, knobs.groupCount - 1) }
            countButton("+") { knobs.groupCount = min(Self.maximumDemoGroupCount, knobs.groupCount + 1) }
        }
    }

    /// 화면을 당기지 않고도 정렬이 바뀌는 걸 볼 수 있게 둔 버튼.
    private var refreshButton: some View {
        Button {
            Task { await store.refresh() }
        } label: {
            Text("새로고침")
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(.white.opacity(0.2), in: .rect(cornerRadius: 8))
                .foregroundStyle(.white)
        }
    }

    private func countButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 28)
            .background(.white.opacity(0.2), in: .rect(cornerRadius: 6))
    }

    /// 체크박스 한 줄. `Toggle` 은 스위치 부분만 눌려 디버그용으로 불편해 행 전체를 버튼으로 만든다.
    private func checkRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(isOn ? Color.cherry500 : .white.opacity(0.6))
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
            }
            .frame(height: 32)
            .contentShape(.rect)
        }
    }

    private static let maximumDemoGroupCount = 12
}

/// 앱 타깃은 기본 격리가 MainActor라, 저장소가 백그라운드에서 읽는 이 값은 명시적으로 풀어 둔다.
private nonisolated struct DemoKnobs: Hashable {
    var groupCount = 5
    var bumpsActivityOnRefresh = false
    var isLoadFailing = false
    var isToppingImageFailing = false
}

/// 패널이 쓰고 저장소가 읽는 공유 상태. 저장소는 어느 스레드에서든 읽으므로 락으로 감싼다.
private nonisolated final class DemoGroupState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedKnobs = DemoKnobs()
    /// 그룹별 마지막 활동 시각. 인덱스 = 그룹이 만들어진 순서(= id 순서)라 정렬과 무관하게 고정이다.
    private var activityDates: [Date] = []
    /// 다음 새로고침에서 최신으로 끌어올릴 그룹.
    private var nextBumpedIndex = 0

    var knobs: DemoKnobs {
        get { lock.withLock { storedKnobs } }
        set { lock.withLock { storedKnobs = newValue } }
    }

    /// 새로고침 한 번 분량의 그룹 목록.
    ///
    /// `bumpsActivityOnRefresh` 가 켜져 있으면 매번 다른 그룹의 활동 시각을 지금으로 올린다 —
    /// id 는 그대로라 같은 그룹이 자리만 옮기는 게 보인다(토핑 그래픽도 따라 움직인다).
    func makeGroups(now: Date) -> [DemoGroupSeed] {
        lock.withLock {
            let count = storedKnobs.groupCount
            growActivityDates(to: count, now: now)

            if storedKnobs.bumpsActivityOnRefresh, count > 0 {
                activityDates[nextBumpedIndex % count] = now
                nextBumpedIndex = (nextBumpedIndex + 1) % count
            }

            return (0..<count).map { index in
                DemoGroupSeed(index: index, lastActivityAt: activityDates[index])
            }
        }
    }

    /// 그룹 수가 늘면 새 그룹은 기존보다 오래된 활동으로 채운다 — 처음 배치가 index 순이 되도록.
    private func growActivityDates(to count: Int, now: Date) {
        while activityDates.count < count {
            activityDates.append(now.addingTimeInterval(-180 * Double(activityDates.count + 1)))
        }
    }
}

/// 저장소가 `ParfaitGroup` 으로 옮기기 전의 데모 데이터 한 줄.
private nonisolated struct DemoGroupSeed {
    let index: Int
    let lastActivityAt: Date
}

/// 데모용 그룹 저장소. 실제 네트워크 대신 패널 값으로 목록을 만들어 낸다.
private struct DemoGroupRepository: GroupRepository {
    let demoState: DemoGroupState

    /// 항상 실패하는 주소 — 토핑 조회 실패 그래픽을 확인하려고 쓴다.
    private static let failingThumbnailURL = URL(string: "https://invalid.parfait.example/topping.png")

    private static let names = [
        "매시업", "잠탈감금", "팀와지", "helloworld", "산책애호가",
        "여덟글자짜리그룹", "아주아주긴그룹이름입니다", "네글자임",
        "AAA", "달콤한푸딩", "몽글한크림", "녹는딸기"
    ]

    func join(inviteCode: String) async throws {}

    func fetchGroups() async throws -> [ParfaitGroup] {
        let knobs = demoState.knobs
        if knobs.isLoadFailing { throw CocoaError(.coderValueNotFound) }

        let now = Date()
        let nametagTypes = NametagType.allCases
        return demoState.makeGroups(now: now).map { seed in
            ParfaitGroup(
                id: "demo-group-\(seed.index)",
                name: Self.names[seed.index % Self.names.count],
                thumbnailURL: knobs.isToppingImageFailing ? Self.failingThumbnailURL : nil,
                lastActivityAt: seed.lastActivityAt,
                createdAt: now.addingTimeInterval(-86_400 * Double(seed.index + 1)),
                lastActorNametagType: nametagTypes[seed.index % nametagTypes.count]
            )
        }
    }
}
#endif
