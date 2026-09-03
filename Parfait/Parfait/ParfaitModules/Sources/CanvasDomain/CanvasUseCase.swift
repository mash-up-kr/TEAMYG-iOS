//
//  CanvasUseCase.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 캔버스 조회·배경 도메인 규칙. 행동별 타입으로 쪼개지 않고 도메인 단위로 모은다(팀 컨벤션).
public protocol CanvasUseCase: Sendable {
    /// 오늘자 캔버스를 가져온다.
    func fetchToday(groupID: Int) async throws -> Parfait

    /// 과거 캔버스를 가져온다.
    func fetchParfait(groupID: Int, parfaitID: Int) async throws -> Parfait

    /// 한 해 전체의 캔버스 요약. 캘린더가 연도를 넘길 때마다 호출한다.
    func fetchSummaries(groupID: Int, year: Int) async throws -> [ParfaitSummary]

    /// 캔버스가 존재하는 연도. 캘린더 연도 목록의 활성 여부를 정한다.
    func fetchYears(groupID: Int) async throws -> [Int]

    /// 배경을 바꾼다. 단색은 HEX 형식을 검증한다.
    func changeBackground(
        groupID: Int,
        parfaitID: Int,
        to background: ParfaitBackgroundChange
    ) async throws -> ParfaitBackground
}

public struct CanvasUseCaseImpl: CanvasUseCase {
    private let canvasRepository: any CanvasRepository

    public init(canvasRepository: any CanvasRepository) {
        self.canvasRepository = canvasRepository
    }

    public func fetchToday(groupID: Int) async throws -> Parfait {
        try await canvasRepository.fetchToday(groupID: groupID)
    }

    public func fetchParfait(groupID: Int, parfaitID: Int) async throws -> Parfait {
        try await canvasRepository.fetchParfait(groupID: groupID, parfaitID: parfaitID)
    }

    /// 기본 조회 범위(30일)에 기대지 않고 해당 연도 전체를 명시한다 — 캘린더는 한 해를 통째로 그린다.
    public func fetchSummaries(groupID: Int, year: Int) async throws -> [ParfaitSummary] {
        try await canvasRepository.fetchSummaries(
            groupID: groupID,
            startDate: ParfaitDate(year: year, month: 1, day: 1),
            endDate: ParfaitDate(year: year, month: 12, day: 31)
        )
    }

    public func fetchYears(groupID: Int) async throws -> [Int] {
        try await canvasRepository.fetchYears(groupID: groupID).sorted()
    }

    public func changeBackground(
        groupID: Int,
        parfaitID: Int,
        to background: ParfaitBackgroundChange
    ) async throws -> ParfaitBackground {
        if case .color(let hex) = background, !HexColor.isValid(hex) {
            throw CanvasError.invalidBackgroundColor
        }
        return try await canvasRepository.changeBackground(
            groupID: groupID,
            parfaitID: parfaitID,
            to: background
        )
    }
}

public enum CanvasError: Error, Equatable {
    case invalidBackgroundColor
}

/// `#RRGGBB` 형식 검증. 서버·안드로이드와 같은 표기를 쓰기 위해 클라이언트에서 먼저 막는다.
public enum HexColor {
    public static func isValid(_ hex: String) -> Bool {
        guard hex.count == 7, hex.hasPrefix("#") else { return false }
        return hex.dropFirst().allSatisfy(\.isHexDigit)
    }
}
