//
//  AppVersionCheck.swift
//  AppVersionDomain
//
//  Created by 박서연 on 11/24/26.
//

import Foundation

public enum AppUpdateType: Sendable {
    case force
    case optional
    case upToDate
}

public struct AppVersionCheck: Sendable {
    public let updateType: AppUpdateType
    public let minimumVersion: String
    public let latestVersion: String
    public let storeURL: URL

    public init(
        updateType: AppUpdateType,
        minimumVersion: String,
        latestVersion: String,
        storeURL: URL
    ) {
        self.updateType = updateType
        self.minimumVersion = minimumVersion
        self.latestVersion = latestVersion
        self.storeURL = storeURL
    }
}
