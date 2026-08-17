// swift-tools-version: 6.2
//  TEAMYG-iOS 레이어별 모듈. 의존 그래프·규칙은 docs/architecture.md 가 원본.
//  타깃 의존성 = import 경계 강제. 안쪽(Domain)으로만 향한다.
//  새 모듈은 아래 `modules` 테이블에 한 줄만 추가 → product+target 자동 생성.
import PackageDescription

// 카탈로그만 콕 집어 .process → 같은 폴더의 생성 .swift(Colors+/Image+)는 소스로 컴파일됨.
// (폴더 통째 .process 하면 .swift 까지 리소스로 복사돼 컴파일 안 됨 — 주의)
let designSystemResources: [Resource] = [
    .process("Resources/Colors.xcassets"),
    .process("Resources/Assets.xcassets"),
    .copy("Resources/SUIT-ttf"), // 폰트: 폴더째 복사(하위경로 유지) → 런타임 등록
]

// (이름, 의존, 리소스)
let modules: [(name: String, dependencies: [String], resources: [Resource])] = [
    ("Common", [], []), // 순수 코드. 의존성 0. (외부 패키지 금지)
    ("Core", ["Common", "Alamofire"], []), // 외부 SDK 기반 공유 구현(네트워크·캐싱). Domain 금지.
    ("UIComponent", ["Common"], designSystemResources), // 공용 UI/디자인 시스템 + MVI 베이스. Domain 금지.
    ("Routing", [], []), // 네비게이션 계약(AppRoute·Router). 페이로드 추가 시 deps 에 도메인.

    // 비즈니스 규칙(UseCase·엔티티·Repository 프로토콜).
    ("AuthDomain", ["Common"], []),
    ("GroupDomain", ["Common"], []),
    ("CanvasDomain", ["Common"], []),
    ("MemberDomain", ["Common"], []),

    // Domain 프로토콜 구현(DTO·매핑·소스).
    ("AuthData", ["AuthDomain", "Core", "Common", "KakaoSDKAuth", "KakaoSDKCommon", "KakaoSDKUser"], []),
    ("GroupData", ["GroupDomain", "Core", "Common"], []),
    ("CanvasData", ["CanvasDomain", "Core", "Common"], []),
    ("MemberData", ["MemberDomain", "Core", "Common"], []),

    // 화면 단위(MVI). 피처끼리 import 금지.
    ("LoginFeature", ["AuthDomain", "Core", "UIComponent", "Routing", "Common"], []),
    ("GroupFeature", ["GroupDomain", "Core", "UIComponent", "Routing", "Common"], []),
    ("CanvasFeature", ["CanvasDomain", "Core", "UIComponent", "Routing", "Common"], []),
    ("SettingFeature", ["Core", "UIComponent", "Routing", "Common"], []),
]

// MARK: 외부 의존성 정의
let externalProducts: [String: String] = [
    "KakaoSDKAuth": "kakao-ios-sdk",
    "KakaoSDKCommon": "kakao-ios-sdk",
    "KakaoSDKUser": "kakao-ios-sdk",
    "Alamofire": "Alamofire",
]

let package = Package(
    name: "ParfaitModules",
    platforms: [.iOS(.v26)],
    products: modules.map { .library(name: $0.name, targets: [$0.name]) },
    dependencies: [
        .package(url: "https://github.com/kakao/kakao-ios-sdk", from: "2.28.0"),
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.12.0")
    ],
    targets: modules.map { module in
        .target(
            name: module.name,
            dependencies: module.dependencies.map { name in
                if let package = externalProducts[name] {
                    return .product(name: name, package: package)
                }
                return .target(name: name)
            },
            resources: module.resources,
            // presentLimitedLibraryPicker 는 PhotosUI 의 ObjC 카테고리 — 심볼 참조가 없어
            // auto-link 가 누락되면 런타임 unrecognized selector 크래시. 명시 링크로 보완.
            // ponytail: 링크 프레임워크가 늘면 modules 테이블 필드로 승격.
            linkerSettings: module.name == "CanvasFeature"
                ? [.linkedFramework("PhotosUI")]
                : nil
        )
    }
)
