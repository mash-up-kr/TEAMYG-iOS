//
//  RecentUploadsStorage.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import Foundation

/// 우리 앱에서 업로드한 이미지의 로컬 기록 저장소.
/// Application Support/RecentUploads/ 에 Data 로 저장하고 URL 만 넘긴다 (메모리 보관 없음 — 결정 사항).
/// 업로드 기능이 생기면 업로드 성공 시점에 `save(_:)` 한 줄로 연결한다.
public actor RecentUploadsStorage {
    private let directoryURL = URL.applicationSupportDirectory.appending(path: "RecentUploads")

    public init() {}

    /// 이미지 데이터를 파일로 저장하고 URL 을 반환한다.
    @discardableResult
    public func save(_ imageData: Data) throws -> URL {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appending(path: "\(UUID().uuidString).jpg")
        try imageData.write(to: fileURL)
        return fileURL
    }

    /// 최신순(파일 수정일 내림차순) URL 목록. IO 실패는 빈 배열로 흡수한다 (스펙: 섹션 숨김).
    public func loadRecentURLs(limit: Int) -> [URL] {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return []
        }
        let sorted = fileURLs.sorted { lhs, rhs in
            modificationDate(of: lhs) > modificationDate(of: rhs)
        }
        return Array(sorted.prefix(limit))
    }

    private func modificationDate(of fileURL: URL) -> Date {
        (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
