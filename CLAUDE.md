# TEAMYG-iOS

> **팀 공용 컨텍스트입니다.** 팀원(김남수·박서연·신상우)과 클로드가 모두 이 규칙을 따릅니다.
> 개인 설정·메모는 `CLAUDE.local.md` / `.claude/settings.local.json` 에 두세요 (커밋 금지).
> 이 파일은 매 세션 로드됩니다 → **짧고 밀도 높게** 유지하세요.

## 개요

iOS 앱 (SwiftUI + Swift Concurrency). **최소 타깃 iOS 26**, 뷰 아키텍처는 **MVI**.

> ⚠️ 아직 Xcode 프로젝트가 스캐폴딩되기 전입니다. 프로젝트 생성 후 아래 `Parfait` 등을 실제 값으로 채우세요.

## 명령어

AI가 **직접 실행해 결과를 검증**할 수 있도록 정확한 명령을 적습니다.
(프로젝트 생성 후 `Parfait`, 시뮬레이터 기종을 확정해 채우세요.)

| 작업 | 명령 |
|------|------|
| 린트 | `swiftlint` |
| 자산(색·이미지) 추가 후 | `cd Parfait/Parfait/ParfaitModules && make assets` → 생성된 `UIComponent/Resources/*+.swift` 커밋 |

> 의존성 관리: **SPM** (레이어별 로컬 패키지 + 외부 의존성). `Package.resolved` 는 커밋합니다.
> 빌드 로그가 길면 `xcbeautify` 파이프 권장: `xcodebuild ... | xcbeautify`.

## 아키텍처

클린 아키텍처 + **레이어별 SPM 로컬 패키지**(`Packages/`). 의존성은 **항상 안쪽(Domain)으로**. 레이어: App / Feature / Domain / Data / Core / UIComponent / Common.

> **모듈·의존 그래프·표·DI·라우팅 상세 규칙 → 모듈/의존성 작업 전 [`docs/architecture.md`](docs/architecture.md) 필독.**

## 컨벤션

> **SwiftLint·SwiftFormat 이 자동으로 잡는 규칙은 여기 쓰지 마세요.** 도구에 위임합니다.
> 도구가 못 잡는 "의도와 맥락"만 적습니다. (아래는 팀 합의로 확정/수정하세요.)

- UI는 SwiftUI 우선. 최소 타깃 **iOS 26** → 최신 SwiftUI/Swift 문법을 먼저 검토해 채택. UIKit 혼용은 PR 설명에 사유 명시.
- 뷰 레이어는 **MVI + `@Observable` 매크로**(단방향). Store 형태·렌더링·바인딩·부수효과 상세 → **Store/View 작업 전 [`docs/mvi.md`](docs/mvi.md) 필독.**
- 비동기는 async/await 사용. 신규 코드에 completion handler 콜백 추가 금지.
- 모델/IO 레이어는 actor/struct 로 동시성 안전하게.
- 의존성은 주입(이니셜라이저 주입)으로. 전역 싱글톤 신규 도입 금지.
- 커밋 메시지는 `type: 설명 (#이슈번호)` 형식 (Conventional Commits). 상세·예시 → [`CONTRIBUTING.md`](CONTRIBUTING.md).

## 용어

- **<도메인 용어>**: <뜻>

## 하지 말 것 (중요)

- API 키·토큰·인증서를 코드/로그/Info.plist 에 하드코딩 금지. (시크릿은 환경/xcconfig + gitignore)
- `main` 직접 push 금지 — PR + 리뷰 후 머지.
- `force unwrap`(`!`) 남발 금지. 옵셔널은 안전하게 언래핑.
- 대용량 바이너리(녹화/스크린샷 원본)를 레포에 커밋 금지.

## 추가 컨텍스트 (선택)

<!-- @경로 구문은 해당 문서를 매 세션 강제 로드합니다(컨텍스트 절감 목적과 반대). 상세 규칙은 본문 "필독" 포인터로 온디맨드 참조하세요. -->
