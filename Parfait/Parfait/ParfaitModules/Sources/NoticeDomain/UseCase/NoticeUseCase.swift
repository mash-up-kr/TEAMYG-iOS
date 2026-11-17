//
//  NoticeUseCase.swift
//  NoticeDomain
//
//  Created by 박서연 on 11/10/26.
//

import Foundation

public protocol NoticeUseCase: Sendable {
    func fetchNotices() async throws -> [Notice]
    func markAsRead(noticeID: Int) async
}

public struct NoticeUseCaseImpl: NoticeUseCase {
    private static let newBadgeDays = 14

    private let noticeRepository: any NoticeRepository

    public init(noticeRepository: any NoticeRepository) {
        self.noticeRepository = noticeRepository
    }

    public func fetchNotices() async throws -> [Notice] {
        let notices = try await noticeRepository.fetchNotices()
        let readNoticeIDs = await noticeRepository.readNoticeIDs()
        let today = Calendar.current.startOfDay(for: .now)
        return notices.map { notice in
            var notice = notice
            notice.isNew = !readNoticeIDs.contains(notice.id)
                && isWithinNewBadgePeriod(publishedDate: notice.publishedDate, today: today)
            return notice
        }
    }

    public func markAsRead(noticeID: Int) async {
        await noticeRepository.markAsRead(noticeID: noticeID)
    }

    private func isWithinNewBadgePeriod(publishedDate: Date?, today: Date) -> Bool {
        guard let publishedDate else { return false }
        let calendar = Calendar.current
        let publishedDay = calendar.startOfDay(for: publishedDate)
        guard let elapsedDays = calendar.dateComponents([.day], from: publishedDay, to: today).day else {
            return false
        }
        return elapsedDays <= Self.newBadgeDays
    }
}
