//
//  PolicyResponseDTO.swift
//  AuthData
//
//  Created by 김남수 on 8/12/26.
//

import Foundation

/// `PolicyResponse` 스키마 대응.
struct PolicyResponseDTO: Decodable, Sendable {
    let policies: [PolicyItemDTO]
}

/// `PolicyItemResponse` 스키마 대응. `type` 은 쓰는 곳이 없어 받지 않는다.
struct PolicyItemDTO: Decodable, Sendable {
    let termsId: Int
    let title: String
    let url: URL
    let required: Bool
}
