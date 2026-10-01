//
//  ParfaitSummariesEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import CanvasDomain
import Core

/// 기간 내 캔버스 요약 목록 (`GET /api/v1/groups/{groupId}/parfaits`).
struct ParfaitSummariesEndpoint: Endpoint {
    let groupID: Int
    let startDate: ParfaitDate
    let endDate: ParfaitDate

    var path: String { "/api/v1/groups/\(groupID)/parfaits" }
    var method: HTTPMethod { .get }
    var task: RequestTask {
        .query(DateRangeQuery(startDate: startDate.isoText, endDate: endDate.isoText))
    }

    struct DateRangeQuery: Encodable, Sendable {
        let from: String
        let to: String

        init(startDate: String, endDate: String) {
            from = startDate
            to = endDate
        }
    }
}
