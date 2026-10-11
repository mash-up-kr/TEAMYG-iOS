//
//  CreatedGroup.swift
//  GroupDomain
//
//  Created by 박서연 on 10/9/26.
//

public struct CreatedGroup: Sendable, Hashable {
    public let id: String
    public let inviteCode: String
    public let memberCount: Int

    public init(id: String, inviteCode: String, memberCount: Int) {
        self.id = id
        self.inviteCode = inviteCode
        self.memberCount = memberCount
    }
}
