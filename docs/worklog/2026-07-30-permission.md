# 앨범 권한 없음 화면 (C-102-Error) 작업 기록

- 스펙: `docs/superpowers/specs/2026-07-30-album-screens-design.md`
- Figma: node 708-2989 / 담당: 에이전트 A

## 진행

- [x] AlbumPermissionDeniedView UI
- [x] 빌드 확인

## 결정

- (스펙 승계) 부제 "카메라 권한" → "갤러리 권한" 수정 — 디자인 오타 확정.
- (스펙 승계) 버튼 폭 YGButton 고정 136 사용 — Figma 내용폭 161.5 수용.
- `import UIKit` 추가 — `UIApplication.openSettingsURLString` 용. 레포 선례(`GroupFeature/InviteCodeView.swift`)와 동일하게 명시 import.
- 간격 리터럴(24/8/2) → UIComponent 간격 토큰 `.gap7`/`.gap3`/`.gap1` 로 교체. 값은 디자인 그대로, 표기만 다른 Feature 들과 통일.
- 경고 아이콘 44 는 대응 토큰이 없어 `warningIconSize` 상수로 명명 — 매직넘버 인라인 회피.
- 빌드: `** BUILD SUCCEEDED **` (iPhone 17 Pro / iOS 26.3.1), 신규 파일 swiftlint 위반 0.

## 검증 (orca-cli 시뮬레이터, 2026-07-30)

- 거부 상태(`simctl privacy revoke photos`) 진입 → 권한 없음 화면 정상 렌더(아이콘 cherry600·수정 문구·YGButton·우상단 X, 내비바 숨김). ✅
- "설정으로 이동" 탭 → 설정 앱 진입 확인. ✅
- 미결정 진입 → 시스템 권한 팝업 자동 표시(Info.plist 문구 노출). "허용 안 함" 분기는 revoke 시나리오로 갈음. ✅
- X 버튼 → dismiss 로 모듈 진입 리스트 복귀. ✅
