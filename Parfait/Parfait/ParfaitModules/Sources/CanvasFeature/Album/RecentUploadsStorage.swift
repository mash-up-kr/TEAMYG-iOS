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

#if DEBUG
import UIKit

extension RecentUploadsStorage {
    /// 디버그 전용: 저장 기록이 없으면 번호 매긴 색상 샘플 이미지를 채운다 (최근 업로드 섹션 UI 테스트용).
    /// 마지막 2장은 파일 생성일을 25시간 전으로 백데이트 → 정책 창 필터가 걸러내는지 확인용 (화면에 안 보여야 정상).
    /// 업로드 기능이 붙으면 이 시딩과 호출부를 삭제한다.
    func seedSampleDataIfEmpty(count: Int = 6) {
        guard loadRecent(limit: 1).isEmpty else { return }
        let colors: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple]
        for index in 0..<count {
            let isBackdated = index >= count - 2
            let size = CGSize(width: 600, height: 600)
            let image = UIGraphicsImageRenderer(size: size).image { context in
                colors[index % colors.count].setFill()
                context.fill(CGRect(origin: .zero, size: size))
                let title = (isBackdated ? "어제 샘플 \(index + 1)" : "샘플 \(index + 1)") as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 72),
                    .foregroundColor: UIColor.white
                ]
                let titleSize = title.size(withAttributes: attributes)
                title.draw(
                    at: CGPoint(x: (size.width - titleSize.width) / 2, y: (size.height - titleSize.height) / 2),
                    withAttributes: attributes
                )
            }
            guard let jpegData = image.jpegData(compressionQuality: 0.8),
                  let stored = try? save(jpegData)
            else { continue }
            if isBackdated {
                let backdate = Date.now.addingTimeInterval(-25 * 60 * 60)
                try? FileManager.default.setAttributes(
                    [.creationDate: backdate],
                    ofItemAtPath: directoryURL.appending(path: stored.id).path()
                )
            }
        }
    }
}
#endif
