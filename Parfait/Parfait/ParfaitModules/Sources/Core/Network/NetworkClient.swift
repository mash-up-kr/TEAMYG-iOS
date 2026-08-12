//
//  NetworkClient.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Alamofire
import Foundation

/// 통신 담당 추상화. Data 레이어는 이 프로토콜만 주입받는다 (테스트 목 지점).
public protocol NetworkClient: Sendable {
    func request<Response: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> Response
}

/// Alamofire 기반 구현체.
public final class NetworkClientImpl: NetworkClient {
    private let session: Session
    private let interceptor: RequestInterceptor?
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// - Parameters:
    ///   - session: 기본값은 로거만 붙은 세션.
    ///   - interceptor: 인증 헤더·401 재시도용. `requiresAuth == false` 인 엔드포인트에는 적용되지 않는다.
    ///     토큰 갱신(refresh) 전용 클라이언트는 nil 로 만들어 재귀를 방지한다.
    public init(
        session: Session = Session(eventMonitors: [NetworkLogger()]),
        interceptor: RequestInterceptor? = nil
    ) {
        self.session = session
        self.interceptor = interceptor
    }

    public func request<Response: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> Response {
        let urlRequest = try makeURLRequest(for: endpoint)
        let response = await session.request(
            urlRequest,
            interceptor: endpoint.requiresAuth ? interceptor : nil
        )
        .validate()
        .serializingData(emptyResponseCodes: [200, 204, 205])
        .response

        switch response.result {
        case .success(let data):
            return try unwrap(data)
        case .failure(let error):
            throw mapFailure(error, data: response.data)
        }
    }
}

private extension NetworkClientImpl {
    func makeURLRequest(for endpoint: some Endpoint) throws -> URLRequest {
        var request = URLRequest(url: API.baseURL.appending(path: endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        do {
            switch endpoint.task {
            case .plain:
                return request
            case .query(let parameters):
                return try URLEncodedFormParameterEncoder.default.encode(
                    parameters,
                    into: request
                )
            case .body(let parameters):
                return try JSONParameterEncoder.default.encode(
                    parameters,
                    into: request
                )
            }
        } catch {
            throw NetworkError.invalidRequest(error)
        }
    }

    /// 봉투(`APIResponse`)를 디코딩해 `success` 면 `data` 를 꺼내고, 아니면 서버 에러로 변환한다.
    /// `data` 가 null 인 성공 응답은 `EmptyDTO` 로 처리한다.
    func unwrap<Response: Decodable & Sendable>(_ data: Data) throws -> Response {
        let envelope: APIResponse<Response>
        do {
            envelope = try decoder.decode(APIResponse<Response>.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
        guard envelope.success else {
            throw NetworkError.server(
                code: envelope.code,
                message: envelope.message,
                errorDetail: envelope.errorDetail
            )
        }
        if let payload = envelope.data {
            return payload
        }
        if let empty = EmptyDTO() as? Response {
            return empty
        }
        throw NetworkError.missingData
    }

    func mapFailure(_ error: AFError, data: Data?) -> NetworkError {
        // TokenInterceptor 가 던진 .unauthorized 등이 AFError 에 감싸여 올라온다
        if let networkError = flattenedNetworkError(from: error) {
            return networkError
        }
        if error.responseCode == 401 {
            return .unauthorized
        }
        if let data,
           let envelope = try? decoder.decode(APIResponse<EmptyDTO>.self, from: data) {
            return .server(
                code: envelope.code,
                message: envelope.message,
                errorDetail: envelope.errorDetail
            )
        }
        return .transport(error)
    }

    func flattenedNetworkError(from error: any Error) -> NetworkError? {
        if let networkError = error as? NetworkError {
            return networkError
        }
        if let underlying = (error as? AFError)?.underlyingError {
            return flattenedNetworkError(from: underlying)
        }
        return nil
    }
}
