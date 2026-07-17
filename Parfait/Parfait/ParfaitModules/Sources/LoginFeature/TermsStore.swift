//
//  TermsStore.swift
//  LoginFeature
//
//  Created by 김남수 on 7/14/26.
//

import SwiftUI
import UIComponent

@Observable @MainActor
public final class TermsStore: MVIStore {
    public private(set) var state = State()

    public init() {}

    public func send(_ intent: Intent) {
        switch intent {
        case .allAgreementTapped:
            // 하나라도 미동의면 전체 동의, 이미 전체 동의면 전체 해제.
            state.agreed = state.isAllAgreed ? [] : Set(TermsItem.allCases)
        case .itemTapped(let item):
            if state.agreed.contains(item) {
                state.agreed.remove(item)
            } else {
                state.agreed.insert(item)
            }
        }
    }

    public struct State: Equatable {
        /// 동의한 약관 집합.
        var agreed: Set<TermsItem> = []

        /// 전체 약관 동의 여부.
        var isAllAgreed: Bool {
            agreed.count == TermsItem.allCases.count
        }

        /// 다음 단계 진행 가능 = 필수 약관 모두 동의.
        var canProceed: Bool {
            TermsItem.required.allSatisfy { agreed.contains($0) }
        }
    }

    public enum Intent {
        case allAgreementTapped
        case itemTapped(TermsItem)
    }
}

/// 약관 항목. UI 전용(서버 저장 없음) — 문구·필수 여부만 보유.
public enum TermsItem: CaseIterable, Hashable {
    case service
    case privacy

    /// 필수 항목만.
    static var required: [TermsItem] {
        allCases.filter(\.isRequired)
    }

    var isRequired: Bool {
        switch self {
        case .service, .privacy: return true
        }
    }

    var title: String {
        switch self {
        case .service: return "서비스 이용약관"
        case .privacy: return "개인정보 처리방침"
        }
    }

    /// 행에 표시되는 문구. `(필수) 서비스 이용약관` 형태.
    var prefixedTitle: String {
        "(\(isRequired ? "필수" : "선택")) \(title)"
    }
}
