//
//  NetworkLogger.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Alamofire
import Foundation
import OSLog

/// 요청/응답 로그 (DEBUG 전용).
public final class NetworkLogger: EventMonitor {
    public let queue = DispatchQueue(label: "com.teamyg.parfait.network-logger")
    private let logger = Logger(subsystem: "com.teamyg.parfait", category: "Network")

    public init() {}

    // requestDidResume 은 URLRequest 생성 전에 불릴 수 있어(레이스) 최종 요청을 직접 받는 훅을 쓴다.
    public func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        #if DEBUG
        let method = urlRequest.httpMethod ?? "?"
        let url = urlRequest.url?.absoluteString ?? "unknown"
        let body = prettyPrinted(urlRequest.httpBody)
        logger.debug("➡️ \(method, privacy: .public) \(url, privacy: .public)\nbody: \(body, privacy: .public)")
        #endif
    }

    public func request<Value>(
        _ request: DataRequest,
        didParseResponse response: DataResponse<Value, AFError>
    ) {
        #if DEBUG
        let statusCode = response.response?.statusCode ?? 0
        let url = request.request?.url?.absoluteString ?? "unknown"
        let body = prettyPrinted(response.data)
        switch response.result {
        case .success:
            logger.debug("✅ [\(statusCode, privacy: .public)] \(url, privacy: .public)\n\(body, privacy: .public)")
        case .failure(let error):
            let message = "❌ [\(statusCode)] \(url) — \(error.localizedDescription)\n\(body)"
            logger.error("\(message, privacy: .public)")
        }
        #endif
    }

    /// JSON 이면 들여쓰기해 반환, 아니면 원문 그대로.
    private func prettyPrinted(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "-" }
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            ),
            let string = String(data: pretty, encoding: .utf8)
        else {
            return String(data: data, encoding: .utf8) ?? "-"
        }
        return string
    }
}
