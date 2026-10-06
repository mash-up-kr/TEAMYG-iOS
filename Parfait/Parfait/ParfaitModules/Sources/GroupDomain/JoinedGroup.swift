//
//  JoinedGroup.swift
//  GroupDomain
//
//  Created by 박서연 on 10/6/26.
//

public struct JoinedGroup: Sendable, Hashable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
