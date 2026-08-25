//
//  CanvasEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import Core

/// 캔버스 조회·배경 변경 엔드포인트 묶음.
/// 경로가 `/api/v1/groups/{groupId}/parfaits` 를 공유해 한 타입으로 모았다.
enum CanvasEndpoint: Endpoint {
    case today(groupID: Int)
    case detail(groupID: Int, parfaitID: Int)
    case summaries(groupID: Int, startDate: ParfaitDate, endDate: ParfaitDate)
    case years(groupID: Int)
    case changeBackground(groupID: Int, parfaitID: Int, background: ParfaitBackgroundChange)

    var path: String {
        switch self {
        case .today(let groupID):
            "\(Self.base(groupID))/today"
        case .detail(let groupID, let parfaitID):
            "\(Self.base(groupID))/\(parfaitID)"
        case .summaries(let groupID, _, _):
            Self.base(groupID)
        case .years(let groupID):
            "\(Self.base(groupID))/year"
        case .changeBackground(let groupID, let parfaitID, _):
            "\(Self.base(groupID))/\(parfaitID)/background"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .today, .detail, .summaries, .years: .get
        case .changeBackground: .patch
        }
    }

    var task: RequestTask {
        switch self {
        case .today, .detail, .years:
            .plain
        case .summaries(_, let startDate, let endDate):
            .query(DateRangeQuery(startDate: startDate.isoText, endDate: endDate.isoText))
        case .changeBackground(_, _, let background):
            .body(BackgroundBody(background))
        }
    }

    private static func base(_ groupID: Int) -> String {
        "/api/v1/groups/\(groupID)/parfaits"
    }

    struct BackgroundBody: Encodable, Sendable {
        let type: String
        let value: String?
        let imageId: Int?

        init(_ background: ParfaitBackgroundChange) {
            switch background {
            case .color(let hex):
                type = "COLOR"
                value = hex
                imageId = nil
            case .image(let imageID):
                type = "IMAGE"
                value = nil
                imageId = imageID
            }
        }
    }
}

/// 조회 기간. 서버 쿼리 키는 `from`·`to` 지만 두 글자 이름은 쓰지 않는다.
private struct DateRangeQuery: Encodable, Sendable {
    let startDate: String
    let endDate: String

    enum CodingKeys: String, CodingKey {
        case startDate = "from"
        case endDate = "to"
    }
}
