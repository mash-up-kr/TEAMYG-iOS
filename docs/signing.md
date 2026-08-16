# 코드 서명 (fastlane match)

> 팀 방침: **Xcode 자동 서명을 쓰지 않는다.** 인증서·프로비저닝 프로파일은 fastlane match 로 관리한다.
> 인증서는 암호화되어 사설 레포에 커밋되고, 팀원은 명령 한 번으로 동기화한다.

## 구성 정보

| 항목 | 값 |
|------|-----|
| 인증서 저장소 | `https://github.com/namsoo5/parfait_certificate` (사설, 암호화) |
| App Store Connect API Key ID | `2A6FANL2GA` (Issuer: `2f41e9d6-66da-4ad5-b0c4-cec6a1646cf6`) |
| Team ID | `64JN25L784` |
| Development 프로파일 | `match Development com.teamyg.parfait` |
| Distribution | match 미관리 — 기존 수동 프로파일 사용 (필요 시 `match appstore` 로 확장) |

## 팀원 온보딩 (실기기 빌드가 필요할 때, 최초 1회)

1. `fastlane` 설치: `gem install fastlane` (rbenv ruby 기준. 실행 에러 나면 `gem install digest-crc` 추가)
2. 관리자에게 **보안 채널로** 두 가지를 받는다: API 키 `.p8` 파일, match 복호화 암호
3. `.p8` 을 레포의 `fastlane/` 폴더에 둔다 (gitignore 되어 있음 — **절대 커밋 금지**)
4. 레포 루트에서 실행:

   ```sh
   fastlane certificates
   ```

   첫 실행 때 match 암호를 물으면 입력 (키체인에 저장돼 이후 안 물음).
   인증서·프로파일이 자동 설치되면 끝.

## 명령 정리

| 명령 | 누가 | 용도 |
|------|------|------|
| `fastlane certificates` | 팀원 공통 | 인증서·프로파일 내려받기 (읽기 전용) |
| `fastlane sync_devices` | 관리자 | `fastlane/devices.txt` 에 UDID 추가 후 — 기기 등록 + 프로파일 재생성 |
| `fastlane bootstrap` | 관리자 | 최초 생성·인증서 만료 시 재생성 |

- 새 실기기 추가 절차: 기기 UDID 를 `fastlane/devices.txt` 에 한 줄 추가(탭 구분) → `fastlane sync_devices` → 팀원들은 `fastlane certificates` 재실행.

## 하지 말 것

- `.p8`·match 암호를 커밋/채팅 로그/이슈에 남기지 않는다 (`.p8` 은 gitignore 됨).
- 개발자 포털에서 match 가 만든 인증서·프로파일(`match ...` 이름)을 수동으로 revoke/수정하지 않는다 — match 저장소와 어긋나 팀 전체가 깨진다.
- 실기기 Run 은 Development 서명으로. Distribution(App Store) 프로파일로 서명된 빌드는 기기 직접 설치가 안 된다 (`0xe800801f` 에러).
