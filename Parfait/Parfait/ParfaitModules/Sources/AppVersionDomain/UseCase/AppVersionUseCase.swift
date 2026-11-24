//
//  AppVersionUseCase.swift
//  AppVersionDomain
//
//  Created by 박서연 on 11/24/26.
//

public protocol AppVersionUseCase: Sendable {
    func checkVersion(currentVersion: String) async throws -> AppVersionCheck
}

public struct AppVersionUseCaseImpl: AppVersionUseCase {
    private let appVersionRepository: any AppVersionRepository

    public init(appVersionRepository: any AppVersionRepository) {
        self.appVersionRepository = appVersionRepository
    }

    public func checkVersion(currentVersion: String) async throws -> AppVersionCheck {
        try await appVersionRepository.checkVersion(currentVersion: currentVersion)
    }
}
