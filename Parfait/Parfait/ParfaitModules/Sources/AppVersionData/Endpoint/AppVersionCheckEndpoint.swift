//
//  AppVersionCheckEndpoint.swift
//  AppVersionData
//
//  Created by 박서연 on 11/24/26.
//

import Core

struct AppVersionCheckEndpoint: Endpoint {
    let version: String

    var path: String { "/api/v1/app-versions/check" }
    var method: HTTPMethod { .get }
    var task: RequestTask { .query(Query(platform: "IOS", version: version)) }
    var requiresAuth: Bool { false }

    struct Query: Encodable, Sendable {
        let platform: String
        let version: String
    }
}
