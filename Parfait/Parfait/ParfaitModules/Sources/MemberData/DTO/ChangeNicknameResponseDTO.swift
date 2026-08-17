//
//  ChangeNicknameResponseDTO.swift
//  MemberData
//
//  Created by 김남수 on 8/17/26.
//

/// `PATCH /api/v1/users/me/nickname` 응답 스키마 대응.
struct ChangeNicknameResponseDTO: Decodable, Sendable {
    let nickname: String
}
