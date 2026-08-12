//
//  TermsView.swift
//  LoginFeature
//
//  Created by 김남수 on 7/14/26.
//

import AuthDomain
import Routing
import SwiftUI
import UIComponent

public struct TermsView: View {
    private let router: Router
    @State private var store: TermsStore
    @Environment(\.openURL) private var openURL

    public init(router: Router, store: TermsStore) {
        self.router = router
        _store = State(initialValue: store)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer().frame(height: 40)

            Text("서비스 이용 약관에\n동의해 주세요")
                .suit(.title01Bold)
                .foregroundStyle(.gray900)

            content

            Spacer()

            YGButton("확인", variant: .large) {
                store.send(.confirmTapped)
            }
            .disabled(!store.state.canProceed)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 20)
        .ygTopBar(.back)
        .ygAlert(
            isPresented: Binding(
                get: { store.state.signupPhase == .failed },
                set: { isPresented in
                    if !isPresented { store.send(.signupFailureAcknowledged) }
                }
            )
        ) {
            YGAlert(title: "회원가입에 실패했어요", subtitle: "잠시 후 다시 시도해 주세요")
        }
        .task {
            store.send(.screenAppeared)
            // 회원가입 완료 이벤트 → 다음 화면으로 이동.
            for await event in store.events {
                switch event {
                case .signupCompleted:
                    // ponytail: 가입 완료 랜딩 = 그룹 대문. 온보딩 다음 단계(닉네임 등) 확정 시 교체.
                    router.push(.group)
                }
            }
        }
        .onDisappear { store.send(.screenDisappeared) }
    }

    // MARK: - 로드 상태별 콘텐츠

    @ViewBuilder
    private var content: some View {
        switch store.state.phase {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        case .failed:
            loadFailure
        case .loaded(let policies):
            allAgreementButton
                .padding(.top, 40)

            VStack(spacing: 0) {
                ForEach(policies) { policy in
                    termRow(policy)
                }
            }
            .padding(.top, 12)
        }
    }

    private var loadFailure: some View {
        VStack(spacing: 16) {
            Text("약관을 불러오지 못했어요.")
                .suit(.body02Regular)
                .foregroundStyle(.gray500)
            Button {
                store.send(.retryTapped)
            } label: {
                Text("다시 시도")
                    .suit(.body01Bold)
                    .foregroundStyle(.gray900)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - 모두 동의하기

    private var allAgreementButton: some View {
        Button {
            store.send(.allAgreementTapped)
        } label: {
            HStack(spacing: 2) {
                Image.icCheckRound
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(store.state.isAllAgreed ? Color.blackFixed : .gray200)
                Text("모두 동의하기")
                    .suit(.body01Bold)
                    .foregroundStyle(.gray900)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(.gray100, in: .rect(cornerRadius: Radius.small))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 개별 약관

    private func termRow(_ policy: Policy) -> some View {
        let isAgreed = store.state.isAgreed(policy)
        let itemColor: Color = isAgreed ? .gray800 : .gray500

        return HStack(spacing: 4) {
            Button {
                store.send(.itemTapped(policy))
            } label: {
                HStack(spacing: 4) {
                    Image.icCheck
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(itemColor)
                    Text("(\(policy.isRequired ? "필수" : "선택")) \(policy.title)")
                        .suit(.body02Regular)
                        .foregroundStyle(itemColor)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                openURL(policy.url)
            } label: {
                Image.icCaretRight
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.gray300)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 36)
    }
}

#Preview {
    TermsView(
        router: .preview,
        store: TermsStore(
            registrationToken: "preview-token",
            policiesUseCase: PreviewPoliciesUseCase(),
            signupUseCase: PreviewSignupUseCase()
        )
    )
}

/// 프리뷰 전용 스텁 — 서버 호출 없이 즉시 성공.
private struct PreviewSignupUseCase: SignupUseCase {
    func signup(registrationToken: String, agreements: [TermsAgreement]) async throws {}
}

/// 프리뷰 전용 스텁 — 서버 호출 없이 즉시 성공.
private struct PreviewPoliciesUseCase: PoliciesUseCase {
    func fetchPolicies() async throws -> [Policy] {
        [
            Policy(
                id: 1,
                title: "서비스 이용약관",
                url: URL(string: "https://example.com")!,
                isRequired: true
            ),
            Policy(
                id: 2,
                title: "개인정보 처리방침",
                url: URL(string: "https://example.com")!,
                isRequired: true
            )
        ]
    }
}
