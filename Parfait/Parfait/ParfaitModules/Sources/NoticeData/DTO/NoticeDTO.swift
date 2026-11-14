//
//  NoticeDTO.swift
//  NoticeData
//
//  Created by 박서연 on 11/10/26.
//

struct NoticeDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let content: String
    let publishedDate: String
}
