//
//  SignupResponseDTO.swift
//  AuthData
//
//  Created by 김남수 on 8/11/26.
//

/// `SignupResponse` 스키마 대응. `expiresIn` 은 401 기반 갱신 전략이라 받지 않는다.
struct SignupResponseDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}
