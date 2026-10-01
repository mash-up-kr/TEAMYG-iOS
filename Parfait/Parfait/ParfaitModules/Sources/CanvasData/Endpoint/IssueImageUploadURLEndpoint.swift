//
//  IssueImageUploadURLEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import CanvasDomain
import Core

/// 이미지 업로드 URL 발급 (`POST /api/v1/images`).
struct IssueImageUploadURLEndpoint: Endpoint {
    let image: ImageUpload

    var path: String { "/api/v1/images" }
    var method: HTTPMethod { .post }
    var task: RequestTask {
        .body(
            Body(
                fileName: image.fileName,
                contentType: image.contentType,
                imageType: image.kind.requestValue
            )
        )
    }

    struct Body: Encodable, Sendable {
        let fileName: String
        let contentType: String
        let imageType: String
    }
}

private extension ImageUpload.Kind {
    var requestValue: String {
        switch self {
        case .topping: "NUKKI"
        case .background: "BACKGROUND"
        }
    }
}
