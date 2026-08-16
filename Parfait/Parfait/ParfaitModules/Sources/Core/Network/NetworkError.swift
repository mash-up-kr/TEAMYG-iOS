//
//  NetworkError.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Foundation

public enum NetworkError: Error, Sendable {
    /// URLRequest 생성·파라미터 인코딩 실패 (프로그래밍 오류에 가까움)
    case invalidRequest(any Error)
    /// 전송 실패 — 타임아웃·오프라인 등
    case transport(any Error)
    /// 서버가 `success == false` 로 응답
    case server(code: String?, message: String?, errorDetail: [String: String]?)
    /// 응답 디코딩 실패
    case decoding(any Error)
    /// `success == true` 인데 `data` 가 없는 응답
    case missingData
    /// 인증 만료 — 토큰 갱신까지 실패한 상태. 재로그인 필요
    case unauthorized
}
