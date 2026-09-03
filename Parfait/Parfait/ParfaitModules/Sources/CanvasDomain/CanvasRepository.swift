//
//  CanvasRepository.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 캔버스 조회·배경 변경 계약.
public protocol CanvasRepository: Sendable {
    /// 오늘자 캔버스. 없으면 서버가 만들어 돌려준다.
    func fetchToday(groupID: Int) async throws -> Parfait

    /// 과거 캔버스 상세. 응답 형태는 오늘자 캔버스와 같다.
    func fetchParfait(groupID: Int, parfaitID: Int) async throws -> Parfait

    /// 기간 안의 캔버스 요약 목록. 캘린더의 기록 날짜와 날짜 → 캔버스 ID 매핑에 쓴다.
    func fetchSummaries(
        groupID: Int,
        startDate: ParfaitDate,
        endDate: ParfaitDate
    ) async throws -> [ParfaitSummary]

    /// 캔버스가 하나라도 존재하는 연도 목록.
    func fetchYears(groupID: Int) async throws -> [Int]

    /// 캔버스 배경을 바꾼다.
    func changeBackground(
        groupID: Int,
        parfaitID: Int,
        to background: ParfaitBackgroundChange
    ) async throws -> ParfaitBackground
}
