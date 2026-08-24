//
//  MyAccountResponseDTO.swift
//  MemberData
//
//  Created by 김남수 on 8/17/26.
//

/// `GET /api/v1/users/me` 응답 스키마 대응.
struct MyAccountResponseDTO: Decodable, Sendable {
    let memberId: Int
    let provider: String
    let nickname: String
}
