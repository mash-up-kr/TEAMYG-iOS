//
//  ParfaitDTO.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

/// `GetTodayParfaitResponse` — 오늘 조회와 과거 상세가 같은 스키마를 쓴다.
struct ParfaitDTO: Decodable, Sendable {
    let parfaitId: Int
    let date: String
    let status: String
    let lastClosedDate: String?
    let groupMembers: [GroupMemberDTO]
    let background: BackgroundDTO?
    let images: [ParfaitImageDTO]?
}

struct GroupMemberDTO: Decodable, Sendable {
    let id: Int
    let nickname: String
    let nameTagChip: String?
}

struct BackgroundDTO: Decodable, Sendable {
    let type: String
    let value: String
}

/// `TodayParfaitImageResponse`. `createdAt` 은 소수 초가 포함될 수 있는 ISO 8601 문자열이라
/// `String` 으로 받아 매핑에서 형식별로 파싱한다.
struct ParfaitImageDTO: Decodable, Sendable {
    let parfaitImageId: Int
    let imageId: Int
    let imageUrl: String
    let positionX: Double
    let positionY: Double
    let positionZ: Int
    let scale: Double
    let rotation: Double
    let borderType: String
    let borderColor: String?
    let borderWidth: Double?
    let placedBy: PlacedByDTO?
    let createdAt: String?
}

struct PlacedByDTO: Decodable, Sendable {
    let groupMemberId: Int
    let nickname: String
    let nameTagChip: String?
    let ownerType: String?
}

/// `PastParfaitsResponse`
struct ParfaitSummaryListDTO: Decodable, Sendable {
    let parfaits: [ParfaitSummaryDTO]
}

struct ParfaitSummaryDTO: Decodable, Sendable {
    let parfaitId: Int
    let date: String
    let thumbnailUrl: String?
    let imageCount: Int
}

/// `ParfaitYearsResponse`
struct ParfaitYearsDTO: Decodable, Sendable {
    let years: [Int]
}

/// `ChangeParfaitBackgroundResponse`
struct ChangeBackgroundResponseDTO: Decodable, Sendable {
    let background: BackgroundDTO
}
