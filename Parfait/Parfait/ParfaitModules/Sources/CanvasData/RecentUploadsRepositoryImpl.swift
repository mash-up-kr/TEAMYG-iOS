//
//  RecentUploadsRepositoryImpl.swift
//  CanvasData
//
//  Created by 김남수 on 8/5/26.
//

import CanvasDomain
import Foundation

/// `RecentUploadsRepository` 파일 구현.
/// Application Support/RecentUploads/ 에 파일로 저장하고, 조회 시 `StoredImage` 로 읽어 넘긴다.
public actor RecentUploadsRepositoryImpl: RecentUploadsRepository {
    private let directoryURL = URL.applicationSupportDirectory.appending(path: "RecentUploads")

    public init() {}

    /// 이미지 데이터를 파일로 저장하고 저장된 기록을 반환한다.
    /// 누끼는 알파가 살아 있어야 해서 PNG 로 보관한다 — C-102 최근 업로드에서 다시 꺼내 쓴다.
    @discardableResult
    public func save(_ imageData: Data) throws -> StoredImage {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).png"
        try imageData.write(to: directoryURL.appending(path: fileName))
        return StoredImage(id: fileName, imageData: imageData, createdAt: .now)
    }

    /// 최신순(파일 생성일 내림차순) 기록 목록. IO 실패는 빈 배열로 흡수한다 (스펙: 섹션 숨김).
    /// `window` 를 주면 그 기간(시작 포함·끝 제외) 안의 기록만 남긴다. 날짜 정렬 후 상위 `limit` 개만 Data 를 읽는다.
    public func loadRecent(limit: Int, within window: DateInterval? = nil) -> [StoredImage] {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return []
        }
        return fileURLs
            .map { fileURL in (fileURL: fileURL, createdAt: creationDate(of: fileURL)) }
            .filter { file in
                guard let window else { return true }
                return window.start <= file.createdAt && file.createdAt < window.end
            }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .compactMap { fileURL, createdAt in
                guard let imageData = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else { return nil }
                return StoredImage(
                    id: fileURL.lastPathComponent,
                    imageData: imageData,
                    createdAt: createdAt
                )
            }
    }

    private func creationDate(of fileURL: URL) -> Date {
        (try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }
}
