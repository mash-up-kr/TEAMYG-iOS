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
/// `send` 는 구독자가 없는 순간의 이벤트를 버린다 — 일회성 알림이라 나중에 몰아서 보여 줄 이유가 없다.
/// 잃으면 안 되는 결과 알림은 `sendOrHold` 로 보낸다.
@MainActor
final class EventChannel<Event: Sendable> {
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]
    /// `sendOrHold` 가 구독자를 못 찾아 붙잡아 둔 이벤트. 다음 구독자에게 순서대로 넘긴다.
    private var heldEvents: [Event] = []

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

        // 아직 `for await` 을 시작하지 않았어도 스트림 버퍼에 쌓이므로 곧바로 흘려 보낸다.
        for heldEvent in heldEvents {
            continuation.yield(heldEvent)
        }
        heldEvents = []

        return stream
    }

    /// 살아 있는 구독자에게 흘린다. 한 명에게라도 닿았으면 `true`.
    ///
    /// 끝난 스트림은 `onTermination` 이 비동기로 정리해 잠깐 목록에 남는다. 그래서 목록 크기가
    /// 아니라 `yield` 결과로 실제 전달 여부를 판단한다.
    @discardableResult
    func send(_ event: Event) -> Bool {
        var didDeliver = false
        for continuation in continuations.values {
            if case .terminated = continuation.yield(event) { continue }
            didDeliver = true
        }
        return didDeliver
    }

    /// 구독자가 없으면 버리지 않고 다음 구독까지 들고 있는다.
    ///
    /// 화면 위에 모달이 덮여 구독이 잠깐 끊긴 사이에 나온 결과 알림(예: 갤러리 저장 완료)을
    /// 잃지 않기 위한 통로다. 모달이 닫히고 화면이 다시 구독하면 그때 도착한다.
    func sendOrHold(_ event: Event) {
        guard !send(event) else { return }
        heldEvents.append(event)
    }
}
