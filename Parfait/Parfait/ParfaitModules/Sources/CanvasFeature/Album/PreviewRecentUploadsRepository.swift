//
//  PreviewRecentUploadsRepository.swift
//  CanvasFeature
//
//  Created by 김남수 on 8/5/26.
//

#if DEBUG
import CanvasDomain
import Foundation

/// 프리뷰 전용 빈 저장소 — 실제 구현(CanvasData)은 Feature 가 import 할 수 없다.
struct PreviewRecentUploadsRepository: RecentUploadsRepository {
    func save(_ imageData: Data) throws -> StoredImage {
        StoredImage(
            id: UUID().uuidString,
            imageData: imageData,
            pixelWidth: 0,
            pixelHeight: 0,
            createdAt: .now
        )
    }

    func loadRecent(limit: Int, within window: DateInterval?) -> [StoredImage] { [] }
}
#endif
