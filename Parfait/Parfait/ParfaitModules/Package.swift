// swift-tools-version: 6.2
//  TEAMYG-iOS 레이어별 모듈. 의존 그래프·규칙은 docs/architecture.md 가 원본.
//  타깃 의존성 = import 경계 강제. 안쪽(Domain)으로만 향한다.
import PackageDescription

let package = Package(
    name: "ParfaitModules",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "Feature", targets: ["Feature"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Core", targets: ["Core"]),
        .library(name: "UIComponent", targets: ["UIComponent"]),
        .library(name: "Common", targets: ["Common"]),
    ],
    targets: [
        // Common — 순수 코드. 의존성 0. (외부 패키지 추가 금지)
        .target(name: "Common"),

        // Core — 외부 SDK 기반 공유 구현체(네트워크·캐싱). Domain 금지.
        .target(name: "Core", dependencies: ["Common"]),

        // Domain — 비즈니스 규칙(UseCase·엔티티·Repository 프로토콜). Common 만.
        .target(name: "Domain", dependencies: ["Common"]),

        // Data — Domain 프로토콜 구현(DTO·매핑·소스). Domain·Core 사용.
        .target(name: "Data", dependencies: ["Domain", "Core", "Common"]),

        // UIComponent — 공용 UI / 디자인 시스템. Domain 금지.
        //  카탈로그만 콕 집어 .process → 같은 폴더의 생성 .swift(Colors+/Assets+)는 소스로 컴파일됨.
        //  (폴더 통째 .process 하면 .swift 까지 리소스로 복사돼 컴파일 안 됨 — 주의)
        .target(
            name: "UIComponent",
            dependencies: ["Common"],
            resources: [
                .process("Resources/Colors.xcassets"),
                .process("Resources/Assets.xcassets"),
            ]
        ),

        // Feature — 화면 단위(MVI). 로그인/그룹/캔버스/설정.
        .target(name: "Feature", dependencies: ["Domain", "Core", "UIComponent", "Common"]),
    ]
)
