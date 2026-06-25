//  Feature 공용 MVI 계약 + 단방향 바인딩 헬퍼. (mvi.md)
//  단일 앱 타깃의 Parfait/Parfait/MVIStore.swift 에서 이리로 이동(원본 ponytail 메모대로).
import SwiftUI

/// MVI Store 계약: 읽기 전용 `state` 스냅샷 + 유일한 변이 입구 `send`.
/// 화면별 Store 가 채택해 `binding(_:_:)` 을 공짜로 얻는다.
@MainActor
public protocol MVIStore: AnyObject, Observable {
    associatedtype State
    associatedtype Intent
    var state: State { get }
    func send(_ intent: Intent)
}

public extension MVIStore {
    /// MVI 단방향을 지키는 양방향 바인딩. get → `state`, set → `send`.
    /// `$store.state` 직접 바인딩 대신 이걸 쓴다.
    func binding<Value>(
        _ keyPath: KeyPath<State, Value>,
        _ intent: @escaping (Value) -> Intent
    ) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.send(intent($0)) }
        )
    }
}
