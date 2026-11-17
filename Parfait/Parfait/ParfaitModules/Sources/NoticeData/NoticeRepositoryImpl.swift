//
//  NoticeRepositoryImpl.swift
//  NoticeData
//
//  Created by 박서연 on 11/10/26.
//

import Core
import Foundation
import NoticeDomain

public actor NoticeRepositoryImpl: NoticeRepository {
    private static let readNoticeIDsKey = "readNoticeIDs"

    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    public func fetchNotices() async throws -> [Notice] {
        let response: [NoticeDTO] = try await networkClient.request(NoticesEndpoint())
        return response.map { notice in
            Notice(
                id: notice.id,
                title: notice.title,
                content: notice.content,
                publishedDate: Self.publishedDate(from: notice.publishedDate)
            )
        }
    }

    public func readNoticeIDs() -> Set<Int> {
        let storedIDs = UserDefaults.standard.array(forKey: Self.readNoticeIDsKey) as? [Int] ?? []
        return Set(storedIDs)
    }

    public func markAsRead(noticeID: Int) {
        var noticeIDs = readNoticeIDs()
        guard noticeIDs.insert(noticeID).inserted else { return }
        UserDefaults.standard.set(Array(noticeIDs), forKey: Self.readNoticeIDsKey)
    }

    private static func publishedDate(from text: String) -> Date? {
        let style = Date.ISO8601FormatStyle(timeZone: .current)
            .year()
            .month()
            .day()
            .dateSeparator(.dash)
        return try? style.parse(text)
    }
}
