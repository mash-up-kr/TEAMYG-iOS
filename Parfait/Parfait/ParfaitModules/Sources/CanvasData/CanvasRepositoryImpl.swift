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
    private let todayCache = TodayParfaitCache()

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    /// 캔버스는 몇 초마다 다시 조회한다 — 마지막 ETag 를 보내 바뀐 게 없으면(304) 들고 있던 값을 돌려준다.
    public func fetchToday(groupID: Int) async throws -> Parfait {
        let cached = await todayCache.entry(groupID: groupID)
        let response: ConditionalResponse<ParfaitDTO> = try await networkClient.request(
            TodayParfaitEndpoint(groupID: groupID),
            ifNoneMatch: cached?.etag
        )
        switch response {
        case .notModified:
            // ETag 를 보냈을 때만 304 가 온다.
            guard let cached else { throw NetworkError.missingData }
            return cached.parfait
        case .modified(let dto, let etag):
            let parfait = try dto.toEntity()
            let entry = etag.map { TodayParfaitCache.Entry(etag: $0, parfait: parfait) }
            await todayCache.store(entry, groupID: groupID)
            return parfait
        }
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

/// 그룹별 마지막 오늘 캔버스와 그 ETag.
private actor TodayParfaitCache {
    struct Entry {
        let etag: String
        let parfait: Parfait
    }

    private var entries: [Int: Entry] = [:]

    func entry(groupID: Int) -> Entry? {
        entries[groupID]
    }

    /// `nil` 이면 지운다 — ETag 없는 응답 뒤엔 조건부로 보내지 않는다.
    func store(_ entry: Entry?, groupID: Int) {
        entries[groupID] = entry
    }
}
