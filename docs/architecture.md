# 아키텍처

> TEAMYG-iOS 모듈 구조·의존 규칙. **Feature/모듈/의존성 추가 작업 전 읽을 것.**
> 한 줄 요약은 루트 `CLAUDE.md`. 뷰 레이어(MVI)는 [`mvi.md`](mvi.md).

클린 아키텍처. 모듈은 **단일 SPM 패키지 `Parfait/Parfait/ParfaitModules`** 안의 레이어별 타깃(`Sources/<Module>/`)이다. 의존성은 **항상 안쪽(Domain)으로** 향하고, import 경계는 `Package.swift` 의 타깃 의존성이 강제한다. 새 모듈은 `Package.swift` 의 `modules` 테이블에 한 줄 추가하면 product·target 이 자동 생성된다.

```
App ─▶ Feature ─▶ Domain ◀─ Data ─▶ Core
          └─▶ Core, UIComponent
Common ◀── 전 계층이 의존 (Common 은 시스템 프레임워크만 — 외부 패키지 import 안 함)
```

| 패키지 | 책임 | import 가능 |
|--------|------|-------------|
| **App** | 진입점·DI 조립(composition root)·라우팅 | 전부 |
| **Feature** | 화면 단위(MVI). 로그인 / 그룹(리스트) / 캔버스(S101·S001) / 설정 | Domain, Core, UIComponent, Common |
| **Domain** | 비즈니스 규칙 — UseCase·엔티티·Repository **프로토콜**. auth / 그룹 / 캔버스 | **Common 만.** 외부 의존 0 |
| **Data** | Domain Repository 프로토콜 **구현** — DTO·매핑·원격/로컬 소스 | Domain, Core, Common |
| **UIComponent** | 공용 UI / 디자인 시스템 + MVI 베이스(`MVIStore`) | Common (Domain 금지) |
| **Routing** | 네비게이션 계약 — `AppRoute`(목적지 enum)·`Router` 프로토콜 | 없음 (페이로드에 Domain 필요 시 deps 추가) |
| **Core** | 외부 의존성을 가진 공유 구현체 — 네트워크 추상화, 이미지 캐싱 등 | Common + 외부 SDK (Domain 금지) |
| **Common** | 순수 코드 — 로거, 베이스 익스텐션. **외부 의존성 0** | 시스템 프레임워크만 (외부 패키지 금지) |

## 규칙

- Domain 은 Core·외부 SDK 를 모른다. 외부 의존이 필요하면 Data 가 Domain 프로토콜을 구현하며 Core 를 사용.
- Common 은 시스템 프레임워크(Foundation 등)만 import — 외부 프레임워크·패키지 추가 금지(`Package.swift` 손대지 말 것).
- 새 화면은 Feature 하위 모듈로.
- 새 외부 SDK는 **도메인 전용인지 먼저 검토**한다. 여러 도메인이 공유하는 인프라(네트워크·캐싱 등)만 Core, 특정 도메인 전용(예: 카카오 로그인 SDK → AuthData)은 해당 Data 타깃에 붙인다. 어느 쪽인지 애매하면 AI가 임의로 정하지 말고 **사람이 결정**한다.
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

Feature 끼리 import 금지이므로 화면 전환은 **Routing 모듈의 계약**(`AppRoute`·`Router`)으로 분리하고 App 이 구현(`App/AppRouter.swift`)·소유한다. 값 기반 `NavigationStack` + `enum AppRoute`. Feature 는 완료/요청 이벤트만 올리고 목적지는 모른다. 딥링크도 같은 `AppRoute` 로 매핑.
