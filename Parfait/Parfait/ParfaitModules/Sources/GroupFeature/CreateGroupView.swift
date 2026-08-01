//
//  CreateGroupView.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import GroupDomain
import SwiftUI
import UIComponent

/// 그룹 만들기 화면 (A-005). 그룹명·그룹 속 내 닉네임·그룹 인원을 받아 새 그룹을 만든다.
/// 세 값 모두 나중에 바꿀 수 없어, 확인 버튼과 생성 사이에 되돌릴 수 없음을 알리는 팝업을 한 번 더 둔다.
public struct CreateGroupView: View {
    @State private var store: CreateGroupStore
    private let onCreated: (YGGroup) -> Void

    @Environment(\.dismiss) private var dismiss

    /// 상단 바 아래 첫 입력까지의 간격.
    private static let topInset: CGFloat = 16
    /// 입력 묶음(그룹명 / 닉네임 / 인원) 사이 간격.
    private static let sectionGap: CGFloat = 32
    private static let horizontalInset: CGFloat = 20

    /// - Parameter onCreated: 생성 성공 시 만들어진 그룹을 넘긴다. 화면 이동은 호출부가 결정한다.
    public init(store: CreateGroupStore, onCreated: @escaping (YGGroup) -> Void = { _ in }) {
        _store = State(initialValue: store)
        self.onCreated = onCreated
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionGap) {
            nameField
            nicknameField
            memberCountSection

            Spacer(minLength: Self.sectionGap)

            YGButton("확인", variant: .large) {
                store.send(.confirmTapped)
            }
            .disabled(!store.state.isConfirmEnabled)
        }
        .padding(.horizontal, Self.horizontalInset)
        .padding(.top, Self.topInset)
        // 디자인상 키보드가 올라와도 확인 버튼은 따라 올라오지 않고 가려진다 (A-005 입력 중).
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.gray50)
        // 입력 영역 아무 데나 누르면 키보드를 내린다 — 가려진 확인 버튼에 닿는 유일한 길이다.
        .contentShape(.rect)
        .onTapGesture { dismissKeyboard() }
        .ygTopBar(.detail(title: "그룹 만들기"))
        .ygPopup(
            isPresented: store.binding(
                \.isCreateConfirmPopupPresented,
                CreateGroupStore.Intent.createConfirmPopupVisibilityChanged
            ),
            title: "\(store.state.name)\(store.state.name.objectParticle) 만들까요?",
            description: "그룹명과 인원수는 추후 변경할 수 없어요\n다시 한번 확인해 주세요",
            secondaryTitle: "취소",
            primaryTitle: "만들기",
            primaryAction: { store.send(.createConfirmed) }
        )
        .ygAlert(
            isPresented: Binding(
                get: { store.state.createError != nil },
                set: { isPresented in
                    if !isPresented { store.send(.failureAcknowledged) }
                }
            )
        ) {
            YGAlert(title: "그룹 만들기 실패", subtitle: createErrorMessage)
        }
        .onChange(of: store.state.createdGroup) { _, createdGroup in
            guard let createdGroup else { return }
            onCreated(createdGroup)
            // ponytail: 캔버스(C-001) 가 붙으면 목록으로 돌아가는 대신 만든 그룹으로 이어져야 한다.
            //           그때까지는 목록으로 되돌려 새 그룹이 늘어난 걸 보여준다.
            dismiss()
        }
        .onDisappear { store.send(.screenDisappeared) }
    }

    // MARK: - 입력

    private var nameField: some View {
        YGTitledTextField(
            title: "그룹명",
            text: store.binding(\.name, CreateGroupStore.Intent.nameChanged),
            placeholder: "그룹명을 입력해 주세요",
            maxLength: GroupNamePolicy.groupName.maximumLength,
            errorMessage: store.state.displayedNameViolation.map { $0.message(subject: "그룹명") }
        )
    }

    private var nicknameField: some View {
        YGTitledTextField(
            title: "그룹 속 내 닉네임",
            text: store.binding(\.nickname, CreateGroupStore.Intent.nicknameChanged),
            placeholder: "닉네임을 입력해 주세요",
            maxLength: GroupNamePolicy.nickname.maximumLength,
            errorMessage: store.state.displayedNicknameViolation.map { $0.message(subject: "닉네임") }
        )
    }

    // MARK: - 그룹 인원

    private var memberCountSection: some View {
        VStack(alignment: .leading, spacing: .gap4) {
            Text("그룹 인원")
                .suit(.body02Regular)
                .foregroundStyle(.gray400)

            MemberCountPicker(
                range: GroupDraft.memberCountRange,
                selection: store.state.memberCount
            ) { memberCount in
                dismissKeyboard()
                store.send(.memberCountTapped(memberCount))
            }

            Text("그룹명과 인원수는 추후 변경할 수 없어요")
                .suit(.caption01Regular)
                .foregroundStyle(.gray300)
        }
    }

    // MARK: - 생성 실패

    private var createErrorMessage: String {
        switch store.state.createError {
        case .duplicatedName: "같은 이름의 그룹을 이미 만들었어요"
        case .server(let message): message
        default: "잠시 후 다시 시도해 주세요"
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - 문구

private extension GroupNameViolation {
    /// 위반 사유별 안내 문구. `subject` 는 "그룹명"·"닉네임" 처럼 필드를 가리키는 말.
    /// ponytail: 디자인 확정 문구 받으면 교체.
    func message(subject: String) -> String {
        switch self {
        case .empty: "\(subject)을 입력해 주세요"
        case .leadingSpace, .trailingSpace: "\(subject) 앞뒤에는 공백을 넣을 수 없어요"
        case .consecutiveSpaces: "공백은 한 칸만 입력할 수 있어요"
        }
    }
}

private extension String {
    /// 마지막 글자의 받침 유무로 고른 목적격 조사("을"/"를").
    /// 받침 판단이 불가능한 끝글자(영문·숫자 등)는 "를" 로 둔다 — 어색함이 덜한 쪽.
    var objectParticle: String {
        guard let lastScalar = unicodeScalars.last?.value,
              (0xAC00...0xD7A3).contains(lastScalar) else { return "를" }
        // 한글 음절 = ((초성 × 21) + 중성) × 28 + 종성. 나머지가 0이면 받침 없음.
        return (lastScalar - 0xAC00) % 28 == 0 ? "를" : "을"
    }
}

// MARK: - Preview

#Preview("빈 입력") {
    NavigationStack {
        CreateGroupView(store: CreateGroupStore(createGroupUseCase: PreviewCreateGroupUseCase()))
    }
}

#Preview("입력 완료") {
    NavigationStack {
        CreateGroupView(store: {
            let store = CreateGroupStore(createGroupUseCase: PreviewCreateGroupUseCase())
            store.send(.nameChanged("우와그룹명"))
            store.send(.nicknameChanged("아니야나그런데기니야"))
            store.send(.memberCountTapped(9))
            return store
        }())
    }
}

#Preview("생성 확인 팝업") {
    NavigationStack {
        CreateGroupView(store: {
            let store = CreateGroupStore(createGroupUseCase: PreviewCreateGroupUseCase())
            store.send(.nameChanged("그룹이름최대열글자"))
            store.send(.nicknameChanged("아니야나그런데기니야"))
            store.send(.memberCountTapped(9))
            store.send(.confirmTapped)
            return store
        }())
    }
}

/// 프리뷰 전용 스텁 — 서버 호출 없이 성공/실패를 즉시 확인 (`createError == nil` 이면 성공).
struct PreviewCreateGroupUseCase: CreateGroupUseCase {
    var createError: CreateGroupError?

    func create(_ draft: GroupDraft) async throws -> YGGroup {
        if let createError {
            throw createError
        }
        return YGGroup(
            id: "preview-created",
            name: draft.name,
            thumbnailURL: nil,
            lastActivityAt: .now,
            createdAt: .now,
            lastActorNametagType: .type1
        )
    }
}
