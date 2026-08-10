//
//  API.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Foundation

public enum API {
    public static let baseURL: URL = {
        let urlString = "" // 개발 서버 (swagger 기준). http 라 ATS 예외 필요
        guard let url = URL(string: urlString) else {
            preconditionFailure("잘못된 baseURL: \(urlString)")
        }
        return url
    }()
}
