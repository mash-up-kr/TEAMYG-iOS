//
//  TermsView.swift
//  LoginFeature
//
//  Created by 김남수 on 7/14/26.
//

import Routing
import SwiftUI
import UIComponent

public struct TermsView: View {
    private let router: Router
    @State private var store: TermsStore

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

            allAgreementButton
                .padding(.top, 40)

            VStack(spacing: 0) {
                ForEach(TermsItem.allCases, id: \.self) { item in
                    termRow(item)
                }
            }
            .padding(.top, 12)

            Spacer()

            YGButton("확인", variant: .large) {
                proceedToNext()
            }
            .disabled(!store.state.canProceed)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 20)
    }

    /// 다음 화면으로 이동. 목적지 미정 — 확정되면 채운다.
    private func proceedToNext() {
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

    private func termRow(_ item: TermsItem) -> some View {
        let isAgreed = store.state.agreed.contains(item)
        let itemColor: Color = isAgreed ? .gray800 : .gray500

        return HStack(spacing: 4) {
            Button {
                store.send(.itemTapped(item))
            } label: {
                HStack(spacing: 4) {
                    Image.icCheck
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(itemColor)
                    Text(item.prefixedTitle)
                        .suit(.body02Regular)
                        .foregroundStyle(itemColor)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                // ponytail: 약관 원문 보기 — 원문 화면/URL 확정되면 연결.
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
    TermsView(router: .preview, store: TermsStore())
}
