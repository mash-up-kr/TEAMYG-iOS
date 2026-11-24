//
//  AppVersionRepository.swift
//  AppVersionDomain
//
//  Created by 박서연 on 11/24/26.
//

public protocol AppVersionRepository: Sendable {
    func checkVersion(currentVersion: String) async throws -> AppVersionCheck
}
