//
//  ImageUploadRepositoryImpl.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import Core
import Foundation

/// 업로드 URL 발급 → S3 전송 → 업로드 확인 세 단계를 한 번의 호출로 묶는다.
/// 확인까지 끝나야 이미지가 `COMPLETED` 가 되고 배치에 쓸 수 있다.
public struct ImageUploadRepositoryImpl: ImageUploadRepository {
    private let networkClient: any NetworkClient
    private let uploader: S3ImageUploader

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
        self.uploader = S3ImageUploader()
    }

    public func upload(_ image: ImageUpload) async throws -> UploadedImage {
        let issued: IssuedUploadURLDTO = try await networkClient.request(
            ImageUploadEndpoint.issueUploadURL(image)
        )
        guard let uploadURL = URL(string: issued.uploadUrl) else {
            throw ParfaitMappingError.malformedURL(issued.uploadUrl)
        }

        try await uploader.upload(image.imageData, to: uploadURL, contentType: image.contentType)

        let confirmed: ConfirmedUploadDTO = try await networkClient.request(
            ImageUploadEndpoint.confirm(imageID: issued.imageId)
        )
        guard let imageURL = URL(string: confirmed.imageUrl) else {
            throw ParfaitMappingError.malformedURL(confirmed.imageUrl)
        }
        return UploadedImage(id: confirmed.imageId, url: imageURL)
    }
}
