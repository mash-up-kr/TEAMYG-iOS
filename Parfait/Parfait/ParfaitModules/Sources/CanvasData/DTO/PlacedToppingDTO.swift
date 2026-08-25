//
//  PlacedToppingDTO.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

/// `PlaceParfaitImageResponse` — 요청에 담아 보낸 테두리 값은 응답에 오지 않는다.
struct PlacedToppingDTO: Decodable, Sendable {
    let parfaitImageId: Int
    let imageId: Int
    let imageUrl: String
    let positionX: Double
    let positionY: Double
    let positionZ: Int
    let scale: Double
    let rotation: Double
    let placedBy: PlacedByDTO?
}

/// `UpdateParfaitImageResponse`
struct UpdatedPlacementDTO: Decodable, Sendable {
    let parfaitImageId: Int
    let positionX: Double
    let positionY: Double
    let positionZ: Int
    let scale: Double
    let rotation: Double
}

/// `UpdateParfaitImageBorderResponse`
struct UpdatedBorderDTO: Decodable, Sendable {
    let parfaitImageId: Int
    let borderType: String
    let borderColor: String?
    let borderWidth: Double?
}
