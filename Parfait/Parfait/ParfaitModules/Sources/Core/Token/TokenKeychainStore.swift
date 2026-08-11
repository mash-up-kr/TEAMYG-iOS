//
//  TokenKeychainStore.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Foundation
import OSLog
import Security

/// Keychain 래퍼 — 토큰 저장 전용.
struct TokenKeychainStore: Sendable {
    enum Key: String {
        case accessToken
        case refreshToken
    }

    let service: String

    func save(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        let query = baseQuery(for: key)
        let attributes = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        #if DEBUG
        // 기기 잠금(errSecInteractionNotAllowed) 등으로 실패해도 호출부는 성공으로 착각한다 → 최소한 흔적은 남긴다
        if status != errSecSuccess {
            Logger(subsystem: "com.teamyg.parfait", category: "Keychain")
                .error("🔑 저장 실패 — \(key.rawValue, privacy: .public) (status \(status, privacy: .public))")
        }
        #endif
    }

    func load(_ key: Key) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: Key) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private func baseQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }
}
