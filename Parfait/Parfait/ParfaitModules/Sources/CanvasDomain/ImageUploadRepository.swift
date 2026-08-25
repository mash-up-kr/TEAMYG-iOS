//
//  ImageUploadRepository.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 이미지 업로드 계약. 업로드 URL 발급·S3 전송·업로드 확인은 구현 세부이며
/// 호출부는 "올리면 쓸 수 있는 이미지가 나온다" 만 안다.
public protocol ImageUploadRepository: Sendable {
    func upload(_ image: ImageUpload) async throws -> UploadedImage
}
