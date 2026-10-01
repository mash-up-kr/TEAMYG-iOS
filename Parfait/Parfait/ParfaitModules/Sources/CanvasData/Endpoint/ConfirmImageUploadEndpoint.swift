//
//  ConfirmImageUploadEndpoint.swift
//  CanvasData
//
//  Created by 박서연 on 9/28/26.
//

import Core

/// 이미지 업로드 확인 (`POST /api/v1/images/{imageId}/confirm`).
struct ConfirmImageUploadEndpoint: Endpoint {
    let imageID: Int

    var path: String { "/api/v1/images/\(imageID)/confirm" }
    var method: HTTPMethod { .post }
}
