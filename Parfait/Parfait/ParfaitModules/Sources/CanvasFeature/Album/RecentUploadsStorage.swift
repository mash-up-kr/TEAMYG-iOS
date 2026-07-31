//
//  RecentUploadsStorage.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import CanvasDomain
import Foundation
import ImageIO

/// 우리 앱에서 업로드한 이미지의 로컬 기록 저장소.
/// Application Support/RecentUploads/ 에 파일로 저장하고, 조회 시 `StoredImage` 로 읽어 넘긴다.
/// 업로드 기능이 생기면 업로드 성공 시점에 `save(_:)` 한 줄로 연결한다.
public actor RecentUploadsStorage {
    private let directoryURL = URL.applicationSupportDirectory.appending(path: "RecentUploads")

    public init() {}

    /// 이미지 데이터를 파일로 저장하고 저장된 기록을 반환한다.
    @discardableResult
    public func save(_ imageData: Data) throws -> StoredImage {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).jpg"
        try imageData.write(to: directoryURL.appending(path: fileName))
        return makeStoredImage(id: fileName, imageData: imageData, createdAt: .now)
    }

    /// 최신순(파일 생성일 내림차순) 기록 목록. IO 실패는 빈 배열로 흡수한다 (스펙: 섹션 숨김).
    /// 날짜 정렬 후 상위 `limit` 개만 Data 를 읽는다.
    public func loadRecent(limit: Int) -> [StoredImage] {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return []
        }
        return fileURLs
            .map { fileURL in (fileURL: fileURL, createdAt: creationDate(of: fileURL)) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .compactMap { fileURL, createdAt in
                guard let imageData = try? Data(contentsOf: fileURL) else { return nil }
                return makeStoredImage(
                    id: fileURL.lastPathComponent,
                    imageData: imageData,
                    createdAt: createdAt
                )
            }
    }

    private func makeStoredImage(id: String, imageData: Data, createdAt: Date) -> StoredImage {
        let pixelSize = pixelSize(of: imageData)
        return StoredImage(
            id: id,
            imageData: imageData,
            pixelWidth: pixelSize.width,
            pixelHeight: pixelSize.height,
            createdAt: createdAt
        )
    }

    /// ImageIO 로 헤더만 파싱해 픽셀 크기를 얻는다 (전체 디코딩 없음). 실패 시 0.
    private func pixelSize(of imageData: Data) -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            return (0, 0)
        }
        return (width, height)
    }

    private func creationDate(of fileURL: URL) -> Date {
        (try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }
}
