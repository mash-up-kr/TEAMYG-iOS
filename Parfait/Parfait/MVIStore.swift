//  MVIStore.swift
//  Feature Store 들의 MVI 공통 계약 + 단방향 바인딩 헬퍼.
//  ponytail: 모듈화 시 Feature 공용(또는 별도 Architecture) 패키지로 이동. 지금은 단일 타깃에 둠.

import SwiftUI

/// MVI Store 계약: 읽기 전용 `state` 스냅샷 + 유일한 변이 입구 `send`.
/// 화면별 Store 는 이 프로토콜을 채택해 `binding(_:_:)` 을 공짜로 얻는다.
@MainActor
protocol MVIStore: AnyObject, Observable {
    associatedtype State
    associatedtype Intent
    var state: State { get }
    func send(_ intent: Intent)
}

extension MVIStore {
    /// MVI 단방향을 지키는 양방향 바인딩.
    /// get → `state` 읽기, set → `send(intent)`. `$store.state` 직접 바인딩 대신 이걸 쓴다.
    ///
    ///     TextField("name", text: store.binding(\.name, Intent.setName))
    ///     Toggle("on", isOn: store.binding(\.isOn, Intent.setOn))
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
