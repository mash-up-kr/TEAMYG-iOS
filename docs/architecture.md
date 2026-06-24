# 아키텍처

> TEAMYG-iOS 모듈 구조·의존 규칙. **Feature/모듈/의존성 추가 작업 전 읽을 것.**
> 한 줄 요약은 루트 `CLAUDE.md`. 뷰 레이어(MVI)는 [`mvi.md`](mvi.md).

클린 아키텍처 + **레이어별 SPM 로컬 패키지**(`Packages/`). 의존성은 **항상 안쪽(Domain)으로** 향하고, import 경계는 각 패키지의 `Package.swift` 가 강제한다.

```
App ─▶ Feature ─▶ Domain ◀─ Data ─▶ Core
          └─▶ Core, UIComponent
Common ◀── 전 계층이 의존 (Common 은 아무것도 import 안 함)
```

| 패키지 | 책임 | import 가능 |
|--------|------|-------------|
| **App** | 진입점·DI 조립(composition root)·라우팅 | 전부 |
| **Feature** | 화면 단위(MVI). 로그인 / 그룹(리스트) / 캔버스(S101·S001) / 설정 | Domain, Core, UIComponent, Common |
| **Domain** | 비즈니스 규칙 — UseCase·엔티티·Repository **프로토콜**. auth / 그룹 / 캔버스 | **Common 만.** 외부 의존 0 |
| **Data** | Domain Repository 프로토콜 **구현** — DTO·매핑·원격/로컬 소스 | Domain, Core, Common |
| **UIComponent** | 공용 UI / 디자인 시스템 | Common (Domain 금지) |
| **Core** | 외부 의존성을 가진 공유 구현체 — 네트워크 추상화, 이미지 캐싱 등 | Common + 외부 SDK (Domain 금지) |
| **Common** | 순수 코드 — 로거, 베이스 익스텐션. **의존성 0** | 없음 |

## 규칙

- Domain 은 Core·외부 SDK 를 모른다. 외부 의존이 필요하면 Data 가 Domain 프로토콜을 구현하며 Core 를 사용.
- Common 은 의존성 제로 유지 — 외부 패키지 추가 금지(`Package.swift` 손대지 말 것).
- 새 화면은 Feature 하위 모듈로, 새 외부 연동은 Core 에 추가.
- MainActor Store 로 넘어가는 타입은 `Sendable` — Entity·DTO 는 값 타입 + Sendable, Data/Core 의 IO 는 actor/async.

## DI — Composition Root(App)

앱 시작 시 의존성 그래프를 1회 조립(`AppDependencies` 등 팩토리 객체), `@Environment` 로 하위에 전달. Store 는 그 팩토리로 생성. **DI 컨테이너 라이브러리·전역 싱글톤 금지** — 이니셜라이저 주입만.

```swift
// App 레이어 — 루트가 소유(싱글톤 아님)
struct AppDependencies {
    let authRepo: AuthRepository      // Data 구현체 주입
    let groupRepo: GroupRepository
    func makeLoginStore() -> LoginStore { .init(auth: authRepo) }
    func makeGroupStore() -> GroupStore { .init(groups: groupRepo) }
}
```

## 라우팅 — App 소유

Feature 끼리 import 금지이므로 화면 전환은 App(또는 별도 Routing 모듈)이 담당. 값 기반 `NavigationStack` + `enum Route`. Feature 는 완료/요청 이벤트만 올리고 목적지는 모른다. 딥링크도 같은 `Route` 로 매핑.
