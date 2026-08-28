//
//  StoredImage.swift
//  CanvasDomain
//
//  Created by 김남수 on 7/31/26.
//

import Foundation

/// 앱이 파일로 보관 중인 이미지의 도메인 모델 (기기 앨범 `PHAsset` 과 구분되는 출처).
public struct StoredImage: Identifiable, Equatable, Sendable {
    /// 저장 파일명(UUID 기반) — 목록 diff 용 안정 식별자. 서버 업로드가 생기면 서버 id 로 대체.
    public let id: String
    public let imageData: Data
    public let createdAt: Date

    public init(id: String, imageData: Data, createdAt: Date) {
        self.id = id
        self.imageData = imageData
        self.createdAt = createdAt
    }
}
