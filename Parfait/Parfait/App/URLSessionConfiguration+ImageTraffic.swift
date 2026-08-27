//
//  URLSessionConfiguration+ImageTraffic.swift
//  Parfait
//
//  Created by 박서연 on 8/27/26.
//

import Foundation

extension URLSessionConfiguration {
    static var imageTraffic: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
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
