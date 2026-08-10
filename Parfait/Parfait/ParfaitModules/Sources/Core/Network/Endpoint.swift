//
//  Endpoint.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Foundation

/// HTTP 메서드. Data 레이어가 Alamofire 를 직접 import 하지 않도록 Core 가 소유한다.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// 요청 파라미터 전달 방식.
public enum RequestTask: Sendable {
    /// 파라미터 없음
    case plain
    /// URL 쿼리 스트링으로 인코딩
    case query(any Encodable & Sendable)
    /// JSON body 로 인코딩
    case body(any Encodable & Sendable)
}

/// API 요청 정의. 각 Data 모듈이 채택해 자기 엔드포인트를 정의한다.
public protocol Endpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var task: RequestTask { get }
    /// false 면 Authorization 헤더를 붙이지 않는다 (로그인 등 공개 API). 기본 true.
    var requiresAuth: Bool { get }
}

public extension Endpoint {
    var task: RequestTask { .plain }
    var requiresAuth: Bool { true }
}
