//
//  CanvasRefreshTicker.swift
//  CanvasFeature
//
//  Created by 박서연 on 9/8/26.
//

import Foundation

@MainActor
final class CanvasRefreshTicker {
    /// 캔버스 자동 최신화 주기. 세 화면이 같은 값을 쓴다.
    static let interval: Duration = .seconds(10)

    private var task: Task<Void, Never>?

    /// 이미 돌고 있으면 다시 시작하지 않는다 — 재진입 때 틱이 겹치지 않게 (`docs/mvi.md`).
    func start(_ tick: @escaping @MainActor @Sendable () -> Void) {
        guard task == nil else { return }
        task = Task {
            while !Task.isCancelled {
                guard (try? await Task.sleep(for: Self.interval)) != nil else { return }
                guard !Task.isCancelled else { return }
                tick()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
