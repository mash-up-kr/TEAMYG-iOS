//
//  SoloSpaceRepositoryImpl.swift
//  CanvasData
//
//  Created by 김남수 on 11/18/26.
//

import CanvasDomain
import Foundation

/// 혼자 공간의 로컬 저장소 (#163). 서버 대신 기기 파일에 캔버스 하나를 보관한다.
///
/// 로그인과 무관하게 기기당 하나 — `Application Support/SoloSpace/` 에 `canvas.json` 과 이미지 파일을 둔다.
/// 처음 읽을 때 빈 캔버스로 만들어지고, 지우면 다음에 읽을 때 다시 만들어진다.
///
/// 캔버스 화면은 그룹 캔버스와 같은 Repository 계약으로 이 저장소를 쓴다. `groupID`·`parfaitID` 인자는 보지 않는다.
/// 매 작업마다 JSON 전체를 읽고 쓴다 — 토핑 수백 개 규모에서 느려지면 메모리 캐시를 둔다.
public actor SoloSpaceRepositoryImpl {
    private let space = SoloSpaceDirectory(
        directoryURL: URL.applicationSupportDirectory.appending(path: "SoloSpace", directoryHint: .isDirectory)
    )
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { .now }) {
        self.now = now
    }

    // MARK: - 파일

    /// 아직 없으면 빈 캔버스로 만들어 돌려준다.
    /// "파일 없음" 일 때만 새로 만든다 — 그 밖의 읽기 실패(기기 잠금 중 파일 보호, I/O 오류)는 던져서
    /// 기존 캔버스를 빈 기록으로 덮어쓰지 않게 한다.
    private func load() throws -> SoloSpaceRecord {
        do {
            let data = try Data(contentsOf: space.recordURL)
            return try JSONDecoder().decode(SoloSpaceRecord.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            try FileManager.default.createDirectory(at: space.imagesURL, withIntermediateDirectories: true)
            let record = SoloSpaceRecord()
            try save(record)
            return record
        }
    }

    private func save(_ record: SoloSpaceRecord) throws {
        try JSONEncoder().encode(record).write(to: space.recordURL, options: .atomic)
    }

    /// 읽고 → 바꾸고 → 쓴다. actor 라 작업끼리 겹치지 않는다.
    /// `change` 가 `discardedFileNames` 에 담은 이미지는 기록을 저장한 **뒤에** 지운다 —
    /// 저장이 실패했는데 파일만 먼저 지워져 기록이 없는 파일을 가리키는 일을 막는다.
    private func update<Result>(
        _ change: (inout SoloSpaceRecord, SoloSpaceDirectory, inout [String]) throws -> Result
    ) async throws -> Result {
        var record = try load()
        var discardedFileNames: [String] = []
        let result = try change(&record, space, &discardedFileNames)
        try save(record)
        for fileName in discardedFileNames {
            try? FileManager.default.removeItem(at: space.imageURL(fileName))
        }
        return result
    }
}

// MARK: - SoloSpaceRepository

extension SoloSpaceRepositoryImpl: SoloSpaceRepository {
    public func reset() async throws {
        let record = try load()
        // 발급한 id 는 이어서 쓴다 — 화면이 들고 있던 옛 id 와 새 토핑이 겹치지 않게.
        // 빈 기록을 먼저 저장하고 이미지를 지운다 — 저장이 실패하면 기존 캔버스가 그대로 남는다.
        try save(SoloSpaceRecord(nextID: record.nextID))
        try? FileManager.default.removeItem(at: space.imagesURL)
        try FileManager.default.createDirectory(at: space.imagesURL, withIntermediateDirectories: true)
    }

    public func delete() async throws {
        try FileManager.default.removeItem(at: space.directoryURL)
    }
}

// MARK: - CanvasRepository

extension SoloSpaceRepositoryImpl: CanvasRepository {
    /// 날짜별 캔버스가 없다 — 오늘자든 과거든 같은 캔버스 하나를 돌려준다.
    public func fetchToday(groupID: Int) async throws -> Parfait {
        parfait(from: try load(), in: space)
    }

    public func fetchParfait(groupID: Int, parfaitID: Int) async throws -> Parfait {
        try await fetchToday(groupID: groupID)
    }

    /// 캘린더를 쓰지 않는다.
    public func fetchSummaries(
        groupID: Int,
        startDate: ParfaitDate,
        endDate: ParfaitDate
    ) async throws -> [ParfaitSummary] {
        []
    }

    public func fetchYears(groupID: Int) async throws -> [Int] {
        []
    }

    public func changeBackground(
        groupID: Int,
        parfaitID: Int,
        to background: ParfaitBackgroundChange
    ) async throws -> ParfaitBackground {
        try await update { record, space, discardedFileNames in
            let newBackground: SoloSpaceRecord.Background
            switch background {
            case .color(let hex):
                newBackground = .color(hex: hex)
            case .image(let imageID):
                guard let fileName = record.uploads.removeValue(forKey: imageID) else {
                    throw SoloSpaceError.imageNotFound
                }
                newBackground = .image(fileName: fileName)
            }
            if case .image(let oldFileName) = record.background {
                discardedFileNames.append(oldFileName)
            }
            record.background = newBackground
            return newBackground.entity(in: space)
        }
    }
}

// MARK: - ImageUploadRepository

extension SoloSpaceRepositoryImpl: ImageUploadRepository {
    /// 서버 대신 이미지 폴더에 저장하고, 배치·배경 변경이 쓸 수 있게 id 를 발급한다.
    public func upload(_ image: ImageUpload) async throws -> UploadedImage {
        try await update { record, space, _ in
            let fileName = "\(UUID().uuidString).\(image.kind == .topping ? "png" : "jpg")"
            let fileURL = space.imageURL(fileName)
            try image.imageData.write(to: fileURL, options: .atomic)
            let id = record.issueID()
            record.uploads[id] = fileName
            return UploadedImage(id: id, url: fileURL)
        }
    }
}

// MARK: - ToppingRepository

extension SoloSpaceRepositoryImpl: ToppingRepository {
    public func place(
        imageID: Int,
        placement: ToppingPlacementValues,
        border: ToppingBorderStyle,
        groupID: Int,
        parfaitID: Int
    ) async throws -> PlacedTopping {
        let createdAt = now()
        return try await update { record, space, _ in
            guard let fileName = record.uploads.removeValue(forKey: imageID) else {
                throw SoloSpaceError.imageNotFound
            }
            let topping = SoloSpaceRecord.Topping(
                id: record.issueID(),
                fileName: fileName,
                placement: .init(placement),
                border: SoloSpaceRecord.Border(border),
                createdAt: createdAt
            )
            record.toppings.append(topping)
            return topping.entity(in: space)
        }
    }

    public func updatePlacements(
        _ updates: [Int: ToppingPlacementUpdate],
        textUpdates: [Int: ToppingPlacementUpdate],
        groupID: Int,
        parfaitID: Int
    ) async throws {
        try await update { record, _, _ in
            for index in record.toppings.indices {
                if let placementUpdate = updates[record.toppings[index].id] {
                    record.toppings[index].placement.apply(placementUpdate)
                }
            }
            for index in record.texts.indices {
                if let placementUpdate = textUpdates[record.texts[index].id] {
                    record.texts[index].placement.apply(placementUpdate)
                }
            }
        }
    }

    public func updateBorder(
        _ border: ToppingBorderStyle,
        toppingID: Int,
        groupID: Int,
        parfaitID: Int
    ) async throws -> ToppingBorderStyle {
        try await update { record, _, _ in
            guard let index = record.toppings.firstIndex(where: { $0.id == toppingID }) else {
                throw SoloSpaceError.toppingNotFound
            }
            record.toppings[index].border = SoloSpaceRecord.Border(border)
            return border
        }
    }

    public func delete(toppingID: Int, groupID: Int, parfaitID: Int) async throws {
        try await update { record, _, discardedFileNames in
            guard let index = record.toppings.firstIndex(where: { $0.id == toppingID }) else { return }
            discardedFileNames.append(record.toppings.remove(at: index).fileName)
        }
    }

    public func placeText(_ draft: TextDraft, groupID: Int, parfaitID: Int) async throws -> PlacedText {
        let createdAt = now()
        return try await update { record, _, _ in
            let text = SoloSpaceRecord.Text(
                id: record.issueID(),
                text: draft.text,
                placement: .init(draft.placement),
                colorHex: draft.colorHex,
                isFill: draft.isFill,
                isStroke: draft.isStroke,
                alignment: .init(draft.alignment),
                createdAt: createdAt
            )
            record.texts.append(text)
            return text.entity(owner: Self.owner)
        }
    }

    public func deleteText(textID: Int, groupID: Int, parfaitID: Int) async throws {
        try await update { record, _, _ in
            record.texts.removeAll { $0.id == textID }
        }
    }
}

// MARK: - 엔티티 조립

extension SoloSpaceRepositoryImpl {
    /// 혼자 공간의 유일한 작성자 — 내 토핑이라 편집할 수 있다.
    /// 로그인과 무관해 계정 id 가 없다 — 편집 가능 여부는 `ownerType` 이 정한다.
    static let owner = ParfaitMember(id: SoloSpace.canvasID, nickname: "나", nametagChip: .type1)
}

private extension SoloSpaceRepositoryImpl {
    func parfait(from record: SoloSpaceRecord, in space: SoloSpaceDirectory) -> Parfait {
        // 캔버스의 하루는 새벽 3시에 바뀐다 — CanvasFeature `CalendarDate(canvasDayContaining:)` 와 같은 규칙.
        // 다르면 0~3시에 화면이 "날짜가 바뀐 응답" 으로 보고 주기 갱신을 버린다.
        let canvasDay = now().addingTimeInterval(-3 * 60 * 60)
        let today = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: canvasDay)
        let owner = Self.owner
        return Parfait(
            id: SoloSpace.canvasID,
            groupName: SoloSpace.name,
            date: ParfaitDate(year: today.year ?? 1970, month: today.month ?? 1, day: today.day ?? 1),
            lastClosedDate: nil,
            members: [owner],
            background: record.background?.entity(in: space),
            toppings: record.toppings.map { $0.entity(in: space) },
            texts: record.texts.map { $0.entity(owner: owner) }
        )
    }
}

enum SoloSpaceError: Error {
    case imageNotFound
    case toppingNotFound
}
