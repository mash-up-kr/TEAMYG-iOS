//
//  NoticeRepository.swift
//  NoticeDomain
//
//  Created by 박서연 on 11/10/26.
//

public protocol NoticeRepository: Sendable {
    func fetchNotices() async throws -> [Notice]
    func readNoticeIDs() async -> Set<Int>
    func markAsRead(noticeID: Int) async
}
