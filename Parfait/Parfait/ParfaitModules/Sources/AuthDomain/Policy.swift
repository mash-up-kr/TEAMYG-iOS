//
//  Policy.swift
//  AuthDomain
//
//  Created by 김남수 on 8/12/26.
//

import Foundation

/// 약관 항목 — 서버 약관 목록 조회(`/api/v1/policies`)가 내려준다.
/// 약관 동의 화면(회원가입)과 설정 화면(약관 보기)이 공용으로 쓴다.
public struct Policy: Identifiable, Hashable, Sendable {
    /// 서버 약관 id — 회원가입 동의 전송(`TermsAgreement.termsId`)에 그대로 쓴다.
    public let id: Int
    public let title: String
    /// 약관 원문 페이지.
    public let url: URL
    public let isRequired: Bool

    public init(id: Int, title: String, url: URL, isRequired: Bool) {
        self.id = id
        self.title = title
        self.url = url
        self.isRequired = isRequired
    }
}
