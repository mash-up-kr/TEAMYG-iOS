//
//  ToppingRepository.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 캔버스에 놓인 토핑의 생성·편집·삭제 계약.
public protocol ToppingRepository: Sendable {
    /// 업로드가 끝난 이미지를 캔버스에 배치한다.
    func place(
        imageID: Int,
        placement: ToppingPlacementValues,
        border: ToppingBorderStyle,
        groupID: Int,
        parfaitID: Int
    ) async throws -> PlacedTopping

    /// 위치·크기·각도를 바꾼다. 값이 있는 필드만 전송된다.
    func updatePlacement(
        _ update: ToppingPlacementUpdate,
        toppingID: Int,
        groupID: Int,
        parfaitID: Int
    ) async throws -> ToppingPlacementValues

    /// 테두리를 바꾼다.
    func updateBorder(
        _ border: ToppingBorderStyle,
        toppingID: Int,
        groupID: Int,
        parfaitID: Int
    ) async throws -> ToppingBorderStyle

    /// 토핑을 지운다.
    func delete(toppingID: Int, groupID: Int, parfaitID: Int) async throws
}
