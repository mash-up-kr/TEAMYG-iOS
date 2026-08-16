//
//  YGLogger.swift
//  Common
//
//  Created by 김남수 on 8/11/26.
//

import OSLog

/// 앱 전역 로거. 호출부는 `YGLogger.log("메시지")` 한 줄이면 된다.
///
/// - `print` 대신 이걸 쓴다. 파일·줄 번호가 자동으로 붙고 Console.app 에서 필터링된다.
/// - **DEBUG 빌드에서만 기록**한다 (릴리즈에선 본문이 통째로 컴파일에서 빠짐).
///   그래서 값을 `.public` 으로 찍어도 사용자 기기 로그에 남지 않는다.
public enum YGLogger {
    /// Console.app 의 필터 축. 로그량이 압도적이거나 놓치면 안 되는 영역만 추가한다.
    public enum Category: String {
        case app = "App"
        case network = "Network"
        case keychain = "Keychain"
    }

    public static func log(
        _ message: String,
        category: Category = .app,
        file: String = #fileID,
        line: Int = #line
    ) {
        write(message, level: .debug, category: category, file: file, line: line)
    }

    public static func error(
        _ message: String,
        category: Category = .app,
        file: String = #fileID,
        line: Int = #line
    ) {
        write(message, level: .error, category: category, file: file, line: line)
    }

    private static func write(
        _ message: String,
        level: OSLogType,
        category: Category,
        file: String,
        line: Int
    ) {
        #if DEBUG
        // 래퍼를 통과한 값은 OSLog 가 기본 <private> 으로 가리므로 명시적으로 .public 을 붙인다
        Logger(subsystem: subsystem, category: category.rawValue).log(
            level: level,
            "[\(file, privacy: .public):\(line, privacy: .public)] \(message, privacy: .public)"
        )
        #endif
    }

    private static let subsystem = "com.teamyg.parfait"
}
