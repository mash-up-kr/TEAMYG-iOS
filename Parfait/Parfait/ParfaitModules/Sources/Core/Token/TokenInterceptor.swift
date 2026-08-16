//
//  TokenInterceptor.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Alamofire
import Foundation

/// 인증 헤더 부착 + 401 시 토큰 갱신 후 1회 재시도.
/// Alamofire 프로토콜이 completion 기반이라 Task 로 브릿지한다 (외부 API 준수 예외).
public final class TokenInterceptor: RequestInterceptor {
    private let tokenManager: TokenManager

    public init(tokenManager: TokenManager) {
        self.tokenManager = tokenManager
    }

    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        Task {
            var request = urlRequest
            if let token = await tokenManager.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            completion(.success(request))
        }
    }

    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: any Error,
        completion: @escaping @Sendable (RetryResult) -> Void
    ) {
        guard request.response?.statusCode == 401, request.retryCount == 0 else {
            return completion(.doNotRetryWithError(error))
        }
        Task {
            do {
                try await tokenManager.refresh()
                completion(.retry)
            } catch NetworkError.server, NetworkError.unauthorized {
                // 서버가 리프레시 토큰 자체를 거절 → 재로그인 외에 방법이 없다.
                // 토큰을 지우고 세션 만료 이벤트를 보내 App 이 로그인 화면으로 되돌리게 한다.
                await tokenManager.expireSession()
                completion(.doNotRetryWithError(NetworkError.unauthorized))
            } catch {
                // 오프라인·타임아웃 등 일시적 실패 — 토큰은 남기고 이번 요청만 실패시킨다
                completion(.doNotRetryWithError(error))
            }
        }
    }
}
