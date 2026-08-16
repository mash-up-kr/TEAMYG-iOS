//
//  RefreshedTokensDTO.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Foundation

/// `ReissueResponse` 스키마 대응. `expiresIn` 은 401 기반 갱신 전략이라 받지 않는다.
struct RefreshedTokensDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}
