//
//  ImageUpload.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

import Foundation

/// 서버에 올릴 이미지 한 장. 업로드는 URL 발급 → S3 전송 → 확인 세 단계지만
/// 도메인에서는 한 번의 요청으로 다룬다.
public struct ImageUpload: Equatable, Sendable {
    public let imageData: Data
    public let fileName: String
    public let contentType: String
    public let kind: Kind

    public init(imageData: Data, fileName: String, contentType: String, kind: Kind) {
        self.imageData = imageData
        self.fileName = fileName
        self.contentType = contentType
        self.kind = kind
    }

    public enum Kind: Sendable {
        /// 캔버스에 올릴 누끼 이미지.
        case topping
        /// 캔버스 배경 이미지.
        case background
    }

    /// 누끼는 항상 알파 PNG 다.
    public static func topping(pngData: Data, fileName: String = "\(UUID().uuidString).png") -> Self {
        Self(imageData: pngData, fileName: fileName, contentType: "image/png", kind: .topping)
    }

    /// 배경 편집에서 방향·크기를 정규화한 JPEG 한 장.
    public static func background(jpegData: Data, fileName: String = "\(UUID().uuidString).jpg") -> Self {
        Self(imageData: jpegData, fileName: fileName, contentType: "image/jpeg", kind: .background)
    }
}

/// 업로드가 끝나 배치·배경 지정에 쓸 수 있는 이미지.
public struct UploadedImage: Equatable, Sendable {
    public let id: Int
    public let url: URL

    public init(id: Int, url: URL) {
        self.id = id
        self.url = url
    }
}
