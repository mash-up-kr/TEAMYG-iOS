//
//  EventChannel.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/27/26.
//

import Foundation

/// 토스트처럼 한 번만 소비해야 하는 이벤트를 화면에 실어 나른다 (`docs/mvi.md`).
///
/// `AsyncStream` 은 단일 소비 전용이라 Store 가 스트림 하나를 들고 있으면,
/// 화면이 사라질 때 `.task` 가 취소되는 순간 스트림 자체가 끝나 버린다.
/// 그러면 화면이 다시 나타나 재구독해도 이벤트가 영영 도착하지 않는다.
/// 여기서는 구독마다 새 스트림을 내주고 발행 시점의 구독자 전원에게 나눠 준다.
///
/// 구독자가 없는 순간의 이벤트는 버린다 — 일회성 알림이라 나중에 몰아서 보여 줄 이유가 없다.
@MainActor
final class EventChannel<Event: Sendable> {
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    /// 새 구독. 소비하는 태스크가 끝나거나 취소되면 이 스트림만 정리되고 채널은 살아 있다.
    func stream() -> AsyncStream<Event> {
        let subscriptionID = UUID()
        let (stream, continuation) = AsyncStream<Event>.makeStream()

        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.continuations[subscriptionID] = nil
            }
        }
        continuations[subscriptionID] = continuation
        return stream
    }

    func send(_ event: Event) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }
}
