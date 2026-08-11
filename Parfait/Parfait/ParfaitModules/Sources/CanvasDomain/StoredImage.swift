//
//  StoredImage.swift
//  CanvasDomain
//
//  Created by 김남수 on 7/31/26.
//

import Foundation

/// 앱이 파일로 보관 중인 이미지의 도메인 모델 (기기 앨범 `PHAsset` 과 구분되는 출처).
/// 원본 데이터와 함께 뷰 레이아웃·정렬에 필요한 메타데이터(픽셀 크기·저장 시각)를 담는다.
public struct StoredImage: Identifiable, Equatable, Sendable {
    /// 저장 파일명(UUID 기반) — 목록 diff 용 안정 식별자. 서버 업로드가 생기면 서버 id 로 대체.
    public let id: String
    public let imageData: Data
    /// 원본 픽셀 크기 — 디코딩 없이 레이아웃(비율) 계산용. 파싱 실패 시 0.
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let createdAt: Date

    /// 가로/세로 비율. 크기를 모르면(0) 정사각형으로 간주한다.
    public var aspectRatio: Double {
        guard pixelWidth > 0, pixelHeight > 0 else { return 1 }
        return Double(pixelWidth) / Double(pixelHeight)
    }

    /// 저장 용량(바이트) — 용량 표시·업로드 제한 검사용.
    public var byteCount: Int { imageData.count }

    public init(
        id: String,
        imageData: Data,
        pixelWidth: Int,
        pixelHeight: Int,
        createdAt: Date
    ) {
        self.id = id
        self.imageData = imageData
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.createdAt = createdAt
    }
}
