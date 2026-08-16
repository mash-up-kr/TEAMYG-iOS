//
//  TermsAgreement.swift
//  AuthDomain
//
//  Created by 김남수 on 8/11/26.
//

/// 약관 항목별 동의 여부 — 회원가입 완료 요청에 실린다.
public struct TermsAgreement: Equatable, Sendable {
    /// 서버 약관 목록 조회(`/api/v1/policies`)가 내려주는 약관 id.
    public let termsId: Int
    public let agreed: Bool

    public init(termsId: Int, agreed: Bool) {
        self.termsId = termsId
        self.agreed = agreed
    }
}
