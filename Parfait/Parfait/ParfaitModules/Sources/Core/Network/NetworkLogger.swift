//
//  NetworkLogger.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Alamofire
import Common
import Foundation

/// 요청/응답 로그 (DEBUG 전용).
/// `#if DEBUG` 은 `YGLogger` 에도 걸려 있지만, 릴리즈에서 `prettyPrinted` 비용까지 없애려고 여기서도 감싼다.
public final class NetworkLogger: EventMonitor {
    public let queue = DispatchQueue(label: "com.teamyg.parfait.network-logger")

    public init() {}

    // requestDidResume 은 URLRequest 생성 전에 불릴 수 있어(레이스) 최종 요청을 직접 받는 훅을 쓴다.
    public func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        #if DEBUG
        let method = urlRequest.httpMethod ?? "?"
        let url = urlRequest.url?.absoluteString ?? "unknown"
        let body = prettyPrinted(urlRequest.httpBody)
        YGLogger.log("➡️ \(method) \(url)\nbody: \(body)", category: .network)
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
            YGLogger.log("✅ [\(statusCode)] \(url)\n\(body)", category: .network)
        case .failure(let error):
            YGLogger.error(
                "❌ [\(statusCode)] \(url) — \(error.localizedDescription)\n\(body)",
                category: .network
            )
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
