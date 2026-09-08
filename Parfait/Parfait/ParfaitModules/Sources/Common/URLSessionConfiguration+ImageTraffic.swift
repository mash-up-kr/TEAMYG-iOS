//
//  URLSessionConfiguration+ImageTraffic.swift
//  Common
//
//  Created by 박서연 on 8/27/26.
//

import Foundation

extension URLSessionConfiguration {
    /// `ImageProvider` 전용 세션 설정 — API 세션과 커넥션·캐시를 나눈다.
    public static var imageTraffic: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        // 토핑 30장이 iOS 기본값(호스트당 4 커넥션)에 걸리면 8파로 나눠 내려온다 —
        // 이미지는 S3(HTTP/1.1) 라 멀티플렉싱이 없어서 이 상한이 그대로 대기 시간이 된다.
        // ponytail: 커넥션만 늘렸다. 여기서 더 빨라져야 하면 서버가 썸네일 크기를 내려줘야 한다.
        configuration.httpMaximumConnectionsPerHost = 8
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 16 * 1_024 * 1_024,
            diskCapacity: 256 * 1_024 * 1_024
        )
        return configuration
    }
}
