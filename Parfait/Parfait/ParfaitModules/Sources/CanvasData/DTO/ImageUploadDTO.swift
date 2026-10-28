//
//  ImageUploadDTO.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

/// `IssueImageUploadUrlResponse`
struct IssuedUploadURLDTO: Decodable, Sendable {
    let imageId: Int
    let uploadUrl: String
}

/// `ConfirmImageUploadResponse`
struct ConfirmedUploadDTO: Decodable, Sendable {
    let imageId: Int
    let imageUrl: String
}
