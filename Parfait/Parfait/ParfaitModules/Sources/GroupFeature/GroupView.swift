import SwiftUI

//  그룹 화면. TODO: Store(MVIStore) + State/Intent, body 구현.
public struct GroupView: View {
    private let makeInviteCodeStore: () -> InviteCodeStore

    public init(makeInviteCodeStore: @escaping () -> InviteCodeStore) {
        self.makeInviteCodeStore = makeInviteCodeStore
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Group")
            // ponytail: 그룹 화면 본 구현 시 실제 진입점 UI로 교체
            NavigationLink("초대코드로 참여", value: GroupRoute.inviteCode)
        }
        .navigationDestination(for: GroupRoute.self) { route in
            switch route {
            case .inviteCode: InviteCodeView(store: makeInviteCodeStore())
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupView(
            makeInviteCodeStore: {
                InviteCodeStore(joinGroupUseCase: PreviewJoinGroupUseCase(joinError: nil))
            }
        )
    }
}
