# TEAMYG-iOS

> **팀 공용 컨텍스트입니다.** 팀원(김남수·박서연·신상우)과 클로드가 모두 이 규칙을 따릅니다.
> 개인 설정·메모는 `CLAUDE.local.md` / `.claude/settings.local.json` 에 두세요 (커밋 금지).
> 이 파일은 매 세션 로드됩니다 → **짧고 밀도 높게** 유지하세요.

## 개요

iOS 앱 (SwiftUI + Swift Concurrency).

> ⚠️ 아직 Xcode 프로젝트가 스캐폴딩되기 전입니다. 프로젝트 생성 후 아래 `<Scheme>` 등을 실제 값으로 채우세요.

## 명령어

AI가 **직접 실행해 결과를 검증**할 수 있도록 정확한 명령을 적습니다.
(프로젝트 생성 후 `<Scheme>`, 시뮬레이터 기종을 확정해 채우세요.)

| 작업 | 명령 |
|------|------|
| 빌드 | `xcodebuild build -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16'` |
| 전체 테스트 | `xcodebuild test -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16'` |
| 단일 테스트 | `xcodebuild test -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:<Target>/<TestCase>/<method>` |
| 린트 | `swiftlint` |
| 포맷 | `swiftformat .` |

> 의존성 관리: <SPM / CocoaPods 중 확정해 기재>. SPM이면 `Package.resolved` 는 커밋합니다.
> 빌드 로그가 길면 `xcbeautify` 파이프 권장: `xcodebuild ... | xcbeautify`.

## 아키텍처

<프로젝트 생성 후 채우기 — 한두 문단 또는 디렉터리 맵>

- `Sources/<App>/` — <앱 진입/공통>
- `Sources/<Feature>/` — <기능 모듈; 상세 규칙은 폴더별 CLAUDE.md 로>

## 컨벤션

> **SwiftLint·SwiftFormat 이 자동으로 잡는 규칙은 여기 쓰지 마세요.** 도구에 위임합니다.
> 도구가 못 잡는 "의도와 맥락"만 적습니다. (아래는 팀 합의로 확정/수정하세요.)

- UI는 SwiftUI 우선. UIKit 혼용이 필요하면 PR 설명에 사유 명시.
- 비동기는 async/await 사용. 신규 코드에 completion handler 콜백 추가 금지.
- UI 상태를 만지는 타입/메서드는 `@MainActor` 로 격리. 모델 레이어는 actor/struct로 동시성 안전하게.
- 의존성은 주입(이니셜라이저 주입)으로. 전역 싱글톤 신규 도입 금지.

## 용어

- **<도메인 용어>**: <뜻>

## 하지 말 것 (중요)

- API 키·토큰·인증서를 코드/로그/Info.plist 에 하드코딩 금지. (시크릿은 환경/xcconfig + gitignore)
- `main` 직접 push 금지 — PR + 리뷰 후 머지.
- `force unwrap`(`!`) 남발 금지. 옵셔널은 안전하게 언래핑.
- 대용량 바이너리(녹화/스크린샷 원본)를 레포에 커밋 금지.

## 추가 컨텍스트 (선택)

<!-- @경로 구문으로 다른 문서를 불러올 수 있습니다. 필요할 때만. -->
<!-- @docs/architecture.md -->
