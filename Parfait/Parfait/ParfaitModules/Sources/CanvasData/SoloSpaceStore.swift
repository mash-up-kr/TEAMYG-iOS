//
//  SoloSpaceStore.swift
//  CanvasData
//
//  Created by 김남수 on 11/18/26.
//

import CanvasDomain
import Foundation

/// 혼자 공간의 로컬 저장소 (#163). 서버 대신 기기 파일에 캔버스 하나를 보관한다.
///
/// 계정별 디렉터리(`Application Support/SoloSpace/<memberID>/`)에 `canvas.json` 과 이미지 파일을 둔다.
/// 로그아웃해도 지우지 않는다 — 같은 계정으로 돌아오면 그대로 이어 쓴다.
///
/// 캔버스 화면은 그룹 캔버스와 같은 Repository 계약으로 이 저장소를 쓴다. `groupID`·`parfaitID` 인자는 보지 않는다.
/// ponytail: 매 작업마다 JSON 전체를 읽고 쓴다. 토핑 수백 개 규모에서 느려지면 메모리 캐시를 둔다.
public actor SoloSpaceStore {
    private let resolveMemberID: @Sendable () async -> Int?
    private let now: @Sendable () -> Date

    /// - Parameter resolveMemberID: 지금 로그인한 계정 ID. 오프라인에서도 답할 수 있도록 App 이 기기에 남긴 값을 먼저 준다.
    public init(
        resolveMemberID: @escaping @Sendable () async -> Int?,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.resolveMemberID = resolveMemberID
        self.now = now
    }

    // MARK: - 파일

    private func currentSpace() async -> SoloSpaceDirectory? {
        guard let memberID = await resolveMemberID() else { return nil }
        let directoryURL = URL.applicationSupportDirectory
            .appending(path: "SoloSpace/\(memberID)", directoryHint: .isDirectory)
        return SoloSpaceDirectory(memberID: memberID, directoryURL: directoryURL)
    }

    private func requireSpace() async throws -> SoloSpaceDirectory {
        guard let space = await currentSpace() else { throw SoloSpaceError.accountUnavailable }
        return space
    }

    private func load(_ space: SoloSpaceDirectory) throws -> SoloSpaceRecord {
        guard let data = try? Data(contentsOf: space.recordURL) else { throw SoloSpaceError.notCreated }
        return try JSONDecoder().decode(SoloSpaceRecord.self, from: data)
    }

    private func save(_ record: SoloSpaceRecord, in space: SoloSpaceDirectory) throws {
        try JSONEncoder().encode(record).write(to: space.recordURL, options: .atomic)
    }

    /// 읽고 → 바꾸고 → 쓴다. actor 라 작업끼리 겹치지 않는다.
    private func update<Result>(
        _ change: (inout SoloSpaceRecord, SoloSpaceDirectory) throws -> Result
    ) async throws -> Result {
        let space = try await requireSpace()
        var record = try load(space)
        let result = try change(&record, space)
        try save(record, in: space)
        return result
    }

    private func removeImage(_ fileName: String, in space: SoloSpaceDirectory) {
        try? FileManager.default.removeItem(at: space.imageURL(fileName))
    }
}

// MARK: - SoloSpaceRepository

extension SoloSpaceStore: SoloSpaceRepository {
    public func exists() async -> Bool {
        guard let space = await currentSpace() else { return false }
        return FileManager.default.fileExists(atPath: space.recordURL.path(percentEncoded: false))
    }

    public func create() async throws {
        guard !(await exists()) else { return }
        let space = try await requireSpace()
        try FileManager.default.createDirectory(at: space.imagesURL, withIntermediateDirectories: true)
        try save(SoloSpaceRecord(), in: space)
    }

    public func reset() async throws {
        let space = try await requireSpace()
        let record = try load(space)
        try? FileManager.default.removeItem(at: space.imagesURL)
        try FileManager.default.createDirectory(at: space.imagesURL, withIntermediateDirectories: true)
        // 발급한 id 는 이어서 쓴다 — 화면이 들고 있던 옛 id 와 새 토핑이 겹치지 않게.
        try save(SoloSpaceRecord(nextID: record.nextID), in: space)
    }
}

// MARK: - CanvasRepository

extension SoloSpaceStore: CanvasRepository {
    /// 날짜별 캔버스가 없다 — 오늘자든 과거든 같은 캔버스 하나를 돌려준다.
    public func fetchToday(groupID: Int) async throws -> Parfait {
        let space = try await requireSpace()
        return parfait(from: try load(space), in: space)
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
        try await update { record, space in
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
                removeImage(oldFileName, in: space)
            }
            record.background = newBackground
            return newBackground.entity(in: space)
        }
    }
}

// MARK: - ImageUploadRepository

extension SoloSpaceStore: ImageUploadRepository {
    /// 서버 대신 이미지 폴더에 저장하고, 배치·배경 변경이 쓸 수 있게 id 를 발급한다.
    public func upload(_ image: ImageUpload) async throws -> UploadedImage {
        try await update { record, space in
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

extension SoloSpaceStore: ToppingRepository {
    public func place(
        imageID: Int,
        placement: ToppingPlacementValues,
        border: ToppingBorderStyle,
        groupID: Int,
        parfaitID: Int
    ) async throws -> PlacedTopping {
        let createdAt = now()
        return try await update { record, space in
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
        try await update { record, _ in
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
        try await update { record, _ in
            guard let index = record.toppings.firstIndex(where: { $0.id == toppingID }) else {
                throw SoloSpaceError.toppingNotFound
            }
            record.toppings[index].border = SoloSpaceRecord.Border(border)
            return border
        }
    }

    public func delete(toppingID: Int, groupID: Int, parfaitID: Int) async throws {
        try await update { record, space in
            guard let index = record.toppings.firstIndex(where: { $0.id == toppingID }) else { return }
            removeImage(record.toppings.remove(at: index).fileName, in: space)
        }
    }

    public func placeText(_ draft: TextDraft, groupID: Int, parfaitID: Int) async throws -> PlacedText {
        let createdAt = now()
        return try await update { record, space in
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
            return text.entity(owner: Self.owner(memberID: space.memberID))
        }
    }

    public func deleteText(textID: Int, groupID: Int, parfaitID: Int) async throws {
        try await update { record, _ in
            record.texts.removeAll { $0.id == textID }
        }
    }
}

// MARK: - 엔티티 조립

private extension SoloSpaceStore {
    static func owner(memberID: Int) -> ParfaitMember {
        ParfaitMember(id: memberID, nickname: "나", nametagChip: .type1)
    }

    func parfait(from record: SoloSpaceRecord, in space: SoloSpaceDirectory) -> Parfait {
        let today = Calendar.current.dateComponents([.year, .month, .day], from: now())
        let owner = Self.owner(memberID: space.memberID)
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
    /// 로그인한 계정 ID 를 모른다 — 한 번도 계정 조회에 성공하지 못했다.
    case accountUnavailable
    case notCreated
    case imageNotFound
    case toppingNotFound
}

// MARK: - 저장 형식

/// 한 계정의 혼자 공간 디렉터리.
private struct SoloSpaceDirectory {
    let memberID: Int
    let directoryURL: URL

    var recordURL: URL { directoryURL.appending(path: "canvas.json") }
    var imagesURL: URL { directoryURL.appending(path: "Images", directoryHint: .isDirectory) }

    func imageURL(_ fileName: String) -> URL { imagesURL.appending(path: fileName) }
}

/// `canvas.json` 의 형식. 이미지는 파일명만 적는다 — 앱 컨테이너 경로는 업데이트마다 바뀔 수 있어 읽을 때 붙인다.
private struct SoloSpaceRecord: Codable {
    var nextID = 1
    /// 업로드했지만 아직 배치·배경에 쓰이지 않은 이미지. 쓰이는 순간 빠진다.
    var uploads: [Int: String] = [:]
    var background: Background?
    var toppings: [Topping] = []
    var texts: [Text] = []

    mutating func issueID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    enum Background: Codable {
        case color(hex: String)
        case image(fileName: String)
    }

    struct Placement: Codable {
        var positionX: Double
        var positionY: Double
        var positionZ: Int
        var scale: Double
        var rotation: Double
    }

    struct Border: Codable {
        let colorHex: String
        let width: Double
    }

    struct Topping: Codable {
        let id: Int
        let fileName: String
        var placement: Placement
        /// `nil` 이면 테두리 없음.
        var border: Border?
        let createdAt: Date
    }

    enum Alignment: String, Codable {
        case left, center, right
    }

    struct Text: Codable {
        let id: Int
        let text: String
        var placement: Placement
        let colorHex: String
        let isFill: Bool
        let isStroke: Bool
        let alignment: Alignment
        let createdAt: Date
    }
}

private extension SoloSpaceRecord.Background {
    func entity(in space: SoloSpaceDirectory) -> ParfaitBackground {
        switch self {
        case .color(let hex): .color(hex: hex)
        case .image(let fileName): .image(url: space.imageURL(fileName))
        }
    }
}

private extension SoloSpaceRecord.Topping {
    func entity(in space: SoloSpaceDirectory) -> PlacedTopping {
        PlacedTopping(
            id: id,
            imageURL: space.imageURL(fileName),
            positionX: placement.positionX,
            positionY: placement.positionY,
            positionZ: placement.positionZ,
            scale: placement.scale,
            rotation: placement.rotation,
            border: border.map { .solid(colorHex: $0.colorHex, width: $0.width) } ?? ToppingBorderStyle.none,
            placedBy: SoloSpaceStore.owner(memberID: space.memberID),
            ownerType: .currentUser,
            createdAt: createdAt
        )
    }
}

private extension SoloSpaceRecord.Text {
    func entity(owner: ParfaitMember) -> PlacedText {
        PlacedText(
            id: id,
            text: text,
            positionX: placement.positionX,
            positionY: placement.positionY,
            positionZ: placement.positionZ,
            scale: placement.scale,
            rotation: placement.rotation,
            colorHex: colorHex,
            isFill: isFill,
            isStroke: isStroke,
            alignment: alignment.entity,
            placedBy: owner,
            ownerType: .currentUser,
            createdAt: createdAt
        )
    }
}

private extension SoloSpaceRecord.Placement {
    init(_ values: ToppingPlacementValues) {
        self.init(
            positionX: values.positionX,
            positionY: values.positionY,
            positionZ: values.positionZ,
            scale: values.scale,
            rotation: values.rotation
        )
    }

    mutating func apply(_ update: ToppingPlacementUpdate) {
        positionX = update.positionX ?? positionX
        positionY = update.positionY ?? positionY
        positionZ = update.positionZ ?? positionZ
        scale = update.scale ?? scale
        rotation = update.rotation ?? rotation
    }
}

private extension SoloSpaceRecord.Border {
    init?(_ style: ToppingBorderStyle) {
        guard case .solid(let colorHex, let width) = style else { return nil }
        self.init(colorHex: colorHex, width: width)
    }
}

private extension SoloSpaceRecord.Alignment {
    init(_ alignment: PlacedTextAlignment) {
        switch alignment {
        case .left: self = .left
        case .center: self = .center
        case .right: self = .right
        }
    }

    var entity: PlacedTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }
}
