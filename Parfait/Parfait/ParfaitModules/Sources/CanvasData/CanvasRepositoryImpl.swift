//
//  CanvasRepositoryImpl.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import Core

public struct CanvasRepositoryImpl: CanvasRepository {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    public func fetchToday(groupID: Int) async throws -> Parfait {
        let dto: ParfaitDTO = try await networkClient.request(TodayParfaitEndpoint(groupID: groupID))
        return try dto.toEntity()
    }

    public func fetchParfait(groupID: Int, parfaitID: Int) async throws -> Parfait {
        let dto: ParfaitDTO = try await networkClient.request(
            ParfaitDetailEndpoint(groupID: groupID, parfaitID: parfaitID)
        )
        return try dto.toEntity()
    }

    public func fetchSummaries(
        groupID: Int,
        startDate: ParfaitDate,
        endDate: ParfaitDate
    ) async throws -> [ParfaitSummary] {
        let dto: ParfaitSummaryListDTO = try await networkClient.request(
            ParfaitSummariesEndpoint(groupID: groupID, startDate: startDate, endDate: endDate)
        )
        return try dto.parfaits.map { try $0.toEntity() }
    }

    public func fetchYears(groupID: Int) async throws -> [Int] {
        let dto: ParfaitYearsDTO = try await networkClient.request(ParfaitYearsEndpoint(groupID: groupID))
        return dto.years
    }

    public func changeBackground(
        groupID: Int,
        parfaitID: Int,
        to background: ParfaitBackgroundChange
    ) async throws -> ParfaitBackground {
        let dto: ChangeBackgroundResponseDTO = try await networkClient.request(
            ChangeParfaitBackgroundEndpoint(
                groupID: groupID,
                parfaitID: parfaitID,
                background: background
            )
        )
        return try dto.background.toEntity()
    }
}
