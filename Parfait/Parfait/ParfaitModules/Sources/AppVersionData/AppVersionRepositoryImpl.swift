//
//  AppVersionRepositoryImpl.swift
//  AppVersionData
//
//  Created by 박서연 on 11/24/26.
//

import AppVersionDomain
import Core

public struct AppVersionRepositoryImpl: AppVersionRepository {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    public func checkVersion(currentVersion: String) async throws -> AppVersionCheck {
        let response: AppVersionCheckDTO = try await networkClient.request(
            AppVersionCheckEndpoint(version: currentVersion)
        )
        return AppVersionCheck(
            updateType: Self.updateType(from: response.updateType),
            minimumVersion: response.minimumVersion,
            latestVersion: response.latestVersion,
            storeURL: response.storeUrl
        )
    }

    private static func updateType(from text: String) -> AppUpdateType {
        switch text {
        case "FORCE":
            .force
        case "OPTIONAL":
            .optional
        default:
            .upToDate
        }
    }
}
