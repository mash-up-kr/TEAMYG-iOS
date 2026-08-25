//
//  S3ImageUploader.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

import Foundation

/// Pre-signed URL 로 S3 에 이미지를 직접 올린다.
///
/// 공용 `NetworkClient` 를 쓰지 않는 이유가 두 가지다. `API.baseURL` 을 항상 앞에 붙여
/// 절대 URL 인 pre-signed URL 을 표현할 수 없고, 서명에 없는 `Authorization` 헤더가 붙으면
/// S3 가 400 을 돌려준다. 그래서 이 단계만 `URLSession` 을 직접 쓴다.
actor S3ImageUploader {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func upload(_ imageData: Data, to uploadURL: URL, contentType: String) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.upload(for: request, from: imageData)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw S3UploadError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw S3UploadError.rejected(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8)
            )
        }
    }
}

enum S3UploadError: Error {
    case invalidResponse
    /// S3 는 오류를 XML 본문으로 돌려준다. 원인 파악에 필요해 그대로 담는다.
    case rejected(statusCode: Int, body: String?)
}
