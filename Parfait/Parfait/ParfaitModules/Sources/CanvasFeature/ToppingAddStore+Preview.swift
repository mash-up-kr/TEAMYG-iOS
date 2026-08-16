//
//  ToppingAddStore+Preview.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/16/26.
//

// ⚠️ 프리뷰 전용 파일 — 제품 코드에서 참조하지 않는다.
//
// `CanvasView.init` 이 `makeToppingAddStore` 팩토리를 요구하므로,
// `#Preview` 블록에서 넘길 "카메라 없는 가짜 팩토리" 가 필요해서 존재한다.
// 실제 카메라 동작 확인은 실기기에서만 가능하고, 여기서는 UI 배치만 보인다.
//
// 프리뷰를 더 이상 쓰지 않게 되면 아래 3곳을 지우면 흔적 없이 제거된다.
//   1. 이 파일 전체
//   2. `CanvasView.swift` 의 `#Preview("Empty")` · `#Preview("Calendar")`
//   3. `ToppingCameraPreviews.swift` 전체 (여기 팩토리를 쓰진 않지만 같은 성격의 프리뷰 전용 파일)
// 제품 코드 수정은 필요 없다.

#if DEBUG
import Foundation

extension ToppingAddStore.Dependencies {
    /// 하드웨어를 건드리지 않고 "항상 성공" 으로 답하는 가짜 의존성.
    static func preview(
        onFlowClosed: @escaping @MainActor @Sendable () async -> Void = {}
    ) -> Self {
        Self(
            previewSource: nil,
            authorizationStatus: { .authorized },
            requestAuthorization: { true },
            startCamera: { _ in true },
            stopCamera: { _ in },
            switchCamera: { nil },
            capturePhoto: { _ in nil },
            openSettings: {},
            onFlowClosed: onFlowClosed
        )
    }
}

extension ToppingAddStore {
    /// `CanvasView` 프리뷰가 `makeToppingAddStore` 자리에 넘기는 팩토리.
    static let previewFactory: ToppingAddStoreFactory = { entryPoint, canvasDate, onFlowClosed in
        ToppingAddStore(
            entryPoint: entryPoint,
            canvasDate: canvasDate,
            dependencies: .preview(onFlowClosed: onFlowClosed)
        )
    }
}
#endif
