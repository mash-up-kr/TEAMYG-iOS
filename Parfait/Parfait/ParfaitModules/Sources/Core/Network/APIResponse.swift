//
//  APIResponse.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Foundation

/// 서버 공통 응답 봉투. 클라이언트 내부에서만 언랩하고, 호출부는 `data` 만 받는다.
struct APIResponse<Payload: Decodable & Sendable>: Decodable, Sendable {
    let success: Bool
    let code: String?
    let message: String?
    let data: Payload?
    let errorDetail: [String: String]?
}

/// `data` 가 없는 응답에 사용하는 빈 페이로드.
public struct EmptyDTO: Decodable, Sendable {
    public init() {}
}
