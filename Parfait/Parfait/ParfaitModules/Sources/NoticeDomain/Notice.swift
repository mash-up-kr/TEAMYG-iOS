//
//  Notice.swift
//  NoticeDomain
//
//  Created by 박서연 on 11/10/26.
//

import Foundation

public struct Notice: Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let content: String
    public let publishedDate: Date?
    public var isNew: Bool

    public init(
        id: Int,
        title: String,
        content: String,
        publishedDate: Date?,
        isNew: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.publishedDate = publishedDate
        self.isNew = isNew
    }
}
