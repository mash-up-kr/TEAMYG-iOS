//
//  ToppingUseCase.swift
//  CanvasDomain
//
//  Created by 박서연 on 8/23/26.
//

/// 토핑 저장·편집 도메인 규칙.
public protocol ToppingUseCase: Sendable {
    /// 누끼를 업로드하고 캔버스에 배치한다. 업로드 → 배치를 한 번에 처리한다.
    func place(_ draft: ToppingDraft, groupID: Int, parfaitID: Int) async throws -> PlacedTopping

    func updatePlacements(
        _ updates: [Int: ToppingPlacementUpdate],
        groupID: Int,
        parfaitID: Int
    ) async throws

    /// 테두리를 바꾼다.
    func updateBorder(
        _ border: ToppingBorderStyle,
        toppingID: Int,
        groupID: Int,
        parfaitID: Int
    ) async throws -> ToppingBorderStyle

    /// 토핑을 지운다.
    func delete(toppingID: Int, groupID: Int, parfaitID: Int) async throws

    /// 텍스트를 캔버스에 배치한다.
    func placeText(_ draft: TextDraft, groupID: Int, parfaitID: Int) async throws -> PlacedText

    /// 텍스트의 위치·크기·회전·색·타입을 바꾼다. 바뀐 것이 없으면 요청하지 않는다.
    func updateText(_ update: TextUpdate, textID: Int, groupID: Int, parfaitID: Int) async throws

    /// 텍스트를 지운다.
    func deleteText(textID: Int, groupID: Int, parfaitID: Int) async throws
}

public struct ToppingUseCaseImpl: ToppingUseCase {
    private let imageUploadRepository: any ImageUploadRepository
    private let toppingRepository: any ToppingRepository

    public init(
        imageUploadRepository: any ImageUploadRepository,
        toppingRepository: any ToppingRepository
    ) {
        self.imageUploadRepository = imageUploadRepository
        self.toppingRepository = toppingRepository
    }

    public func place(_ draft: ToppingDraft, groupID: Int, parfaitID: Int) async throws -> PlacedTopping {
        try Self.validate(draft.border)
        let uploaded = try await imageUploadRepository.upload(draft.image)
        return try await toppingRepository.place(
            imageID: uploaded.id,
            placement: draft.placement,
            border: draft.border,
            groupID: groupID,
            parfaitID: parfaitID
        )
    }

    public func updatePlacements(
        _ updates: [Int: ToppingPlacementUpdate],
        groupID: Int,
        parfaitID: Int
    ) async throws {
        guard !updates.isEmpty else { return }
        try await toppingRepository.updatePlacements(updates, groupID: groupID, parfaitID: parfaitID)
    }

    public func updateBorder(
        _ border: ToppingBorderStyle,
        toppingID: Int,
        groupID: Int,
        parfaitID: Int
    ) async throws -> ToppingBorderStyle {
        try Self.validate(border)
        return try await toppingRepository.updateBorder(
            border,
            toppingID: toppingID,
            groupID: groupID,
            parfaitID: parfaitID
        )
    }

    public func delete(toppingID: Int, groupID: Int, parfaitID: Int) async throws {
        try await toppingRepository.delete(toppingID: toppingID, groupID: groupID, parfaitID: parfaitID)
    }

    public func placeText(_ draft: TextDraft, groupID: Int, parfaitID: Int) async throws -> PlacedText {
        // 서버도 공백만 있는 글을 거절한다 — 요청 전에 막는다.
        guard !draft.text.allSatisfy(\.isWhitespace) else { throw ToppingError.blankText }
        guard HexColor.isValid(draft.colorHex) else { throw ToppingError.invalidTextColor }
        return try await toppingRepository.placeText(draft, groupID: groupID, parfaitID: parfaitID)
    }

    public func updateText(_ update: TextUpdate, textID: Int, groupID: Int, parfaitID: Int) async throws {
        guard !update.isEmpty else { return }
        if let colorHex = update.colorHex, !HexColor.isValid(colorHex) { throw ToppingError.invalidTextColor }
        try await toppingRepository.updateText(update, textID: textID, groupID: groupID, parfaitID: parfaitID)
    }

    public func deleteText(textID: Int, groupID: Int, parfaitID: Int) async throws {
        try await toppingRepository.deleteText(textID: textID, groupID: groupID, parfaitID: parfaitID)
    }

    /// 좌표는 캔버스를 벗어나도 보정하지 않는다(제품 정책). 테두리 값만 범위를 지킨다.
    private static func validate(_ border: ToppingBorderStyle) throws {
        guard case .solid(let colorHex, let width) = border else { return }
        guard HexColor.isValid(colorHex) else { throw ToppingError.invalidBorderColor }
        guard ToppingBorderStyle.widthRange.contains(width) else { throw ToppingError.invalidBorderWidth }
    }
}

public enum ToppingError: Error, Equatable {
    case invalidBorderColor
    case invalidBorderWidth
    case blankText
    case invalidTextColor
}
