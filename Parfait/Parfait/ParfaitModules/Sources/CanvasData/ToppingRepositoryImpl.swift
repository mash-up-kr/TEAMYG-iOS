//
//  ToppingRepositoryImpl.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import Core

public struct ToppingRepositoryImpl: ToppingRepository {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    /// 배치 응답에는 테두리 필드가 없다. 보낸 값을 그대로 엔티티에 실어 돌려준다.
    public func place(
        imageID: Int,
        placement: ToppingPlacementValues,
        border: ToppingBorderStyle,
        groupID: Int,
        parfaitID: Int
    ) async throws -> PlacedTopping {
        let dto: PlacedToppingDTO = try await networkClient.request(
            ToppingEndpoint.place(
                groupID: groupID,
                parfaitID: parfaitID,
                imageID: imageID,
                placement: placement,
                border: border
            )
        )
        return try dto.toEntity(border: border)
    }

    public func updatePlacement(
        _ update: ToppingPlacementUpdate,
        toppingID: Int,
        groupID: Int,
        parfaitID: Int
    ) async throws -> ToppingPlacementValues {
        let dto: UpdatedPlacementDTO = try await networkClient.request(
            ToppingEndpoint.updatePlacement(
                groupID: groupID,
                parfaitID: parfaitID,
                toppingID: toppingID,
                update: update
            )
        )
        return dto.toEntity()
    }

    public func updateBorder(
        _ border: ToppingBorderStyle,
        toppingID: Int,
        groupID: Int,
        parfaitID: Int
    ) async throws -> ToppingBorderStyle {
        let dto: UpdatedBorderDTO = try await networkClient.request(
            ToppingEndpoint.updateBorder(
                groupID: groupID,
                parfaitID: parfaitID,
                toppingID: toppingID,
                border: border
            )
        )
        return dto.toEntity()
    }

    public func delete(toppingID: Int, groupID: Int, parfaitID: Int) async throws {
        let _: EmptyDTO = try await networkClient.request(
            ToppingEndpoint.delete(groupID: groupID, parfaitID: parfaitID, toppingID: toppingID)
        )
    }
}
