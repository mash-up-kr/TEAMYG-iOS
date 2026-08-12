//
//  RecentUploadsRepository.swift
//  CanvasDomain
//
//  Created by 김남수 on 8/5/26.
//

import Foundation

/// 우리 앱에서 업로드한 이미지의 로컬 기록 계약.
/// 업로드 기능이 붙으면 업로드 성공 시점에 `save(_:)` 를 호출해 기록을 남긴다.
public protocol RecentUploadsRepository: Sendable {
    /// 이미지 데이터를 기록으로 저장하고 저장된 결과를 반환한다.
    @discardableResult
    func save(_ imageData: Data) async throws -> StoredImage

    /// 최신순 기록 목록. `window` 를 주면 그 기간(시작 포함·끝 제외) 안의 기록만 남긴다.
    func loadRecent(limit: Int, within window: DateInterval?) async -> [StoredImage]
}
