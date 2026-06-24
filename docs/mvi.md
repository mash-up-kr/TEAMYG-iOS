# MVI (뷰 레이어)

> Feature 의 Store/View 작업 전 읽을 것. 헬퍼: `Parfait/Parfait/MVIStore.swift`.
> 한 줄 요약은 루트 `CLAUDE.md`. 모듈 구조는 [`architecture.md`](architecture.md).

## Store 형태

Store 는 `@Observable @MainActor`, 단일 `private(set) var state: State`(struct) + `send(_ intent: Intent)`(enum 으로 reify). View 는 `state` 만 읽고 `Intent` 만 보낸다. **상태 변이는 `send` 내부에서만.**

```swift
@Observable @MainActor
final class CanvasStore: MVIStore {
    private(set) var state = State()
    func send(_ intent: Intent) {
        switch intent {
        case .rename(let n): state.name = n
        case .zoom(let z):   state.zoom = z
        }
    }
    struct State: Equatable { var name = ""; var zoom = 1.0 }
    enum Intent { case rename(String), zoom(Double) }
}
```

## 렌더링 (불필요한 재평가 줄이기)

`@Observable` 추적 단위는 클래스 프로퍼티 하나(`\.state`). 단일 state struct면 한 필드만 바뀌어도 `state` 읽은 뷰가 전부 body 재평가됨(드로잉은 diff 가 막음).

- **leaf 뷰엔 store 통째로 넘기지 말고 필요한 값만 전달** → 입력 안 바뀐 leaf 는 body 재평가 스킵. 거친 무효화를 부모 1개 재평가로 가둠.
- state 평탄화(필드를 Store 프로퍼티로 분리 / 중첩 `@Observable`)는 **프로파일링으로 병목 확인된 고빈도 화면만**. 기본은 단일 state.

## 바인딩

양방향 바인딩은 `store.binding(\.field, Intent.case)`(get=state, set=send) 어댑터로. **`$store.state` 직접 바인딩 금지**(set 이 `send` 우회). 타이핑·드래그 등 고빈도 입력은 로컬 `@State` + 종료/디바운스 시점에 `send`.

```swift
TextField("name", text: store.binding(\.name, Intent.rename))
```

## 부수효과·이벤트

- 비동기는 `send` 가 `Task` 로 실행하고 Store 가 핸들 보유 → **화면 이탈 시 취소**. 진행 중 작업은 재진입 시 중복 실행 금지.
- 일회성 이벤트(네비게이션·토스트·햅틱)는 `state` 가 아니라 **별도 이벤트 채널**(`AsyncStream` 등)로. state 에 넣으면 재진입 시 재발화됨.
- 로딩/에러는 흩어진 bool 말고 `enum Phase { idle, loading, loaded(T), failed(E) }` 로 표현.

## 관찰·동시성

관찰 객체는 **`@Observable` 매크로** 사용. `ObservableObject`·`@Published`·`@StateObject` 신규 도입 금지(`@State`/`@Bindable` 로). Store 는 `@MainActor @Observable`, 모델/IO 레이어는 actor/struct.
