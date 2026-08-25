//
//  ImageUploadEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import Core

/// 업로드 URL 발급(`POST /api/v1/images`)과 업로드 확인(`POST /api/v1/images/{imageId}/confirm`).
/// 사이의 S3 전송은 서버 API 가 아니라 `S3ImageUploader` 가 맡는다.
enum ImageUploadEndpoint: Endpoint {
    case issueUploadURL(ImageUpload)
    case confirm(imageID: Int)

    var path: String {
        switch self {
        case .issueUploadURL: "/api/v1/images"
        case .confirm(let imageID): "/api/v1/images/\(imageID)/confirm"
        }
    }

    var method: HTTPMethod { .post }

    var task: RequestTask {
        switch self {
        case .issueUploadURL(let image):
            .body(
                Body(
                    fileName: image.fileName,
                    contentType: image.contentType,
                    imageType: image.kind.requestValue
                )
            )
        case .confirm:
            .plain
        }
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
