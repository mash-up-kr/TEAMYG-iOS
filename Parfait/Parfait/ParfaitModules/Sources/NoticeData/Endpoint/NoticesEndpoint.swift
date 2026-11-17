//
//  NoticesEndpoint.swift
//  NoticeData
//
//  Created by 박서연 on 11/10/26.
//

import Core

struct NoticesEndpoint: Endpoint {
    var path: String { "/api/v1/notices" }
    var method: HTTPMethod { .get }
    var task: RequestTask { .query(Query(platform: "IOS")) }

    struct Query: Encodable, Sendable {
        let platform: String
    }
}
