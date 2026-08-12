//
//  ToppingCameraPreviews.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

#if DEBUG
import SwiftUI
import UIComponent

struct CameraPreviewPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.80, blue: 0.74),
                    Color(red: 0.66, green: 0.63, blue: 0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.77, green: 0.66, blue: 0.44))
                .frame(width: 220, height: 300)
                .rotationEffect(.degrees(-7))
                .shadow(color: .black25, radius: 12, y: 8)

            Image(systemName: "camera.macro")
                .font(.system(size: 88, weight: .medium))
                .foregroundStyle(.whiteFixed.opacity(0.9))
        }
    }
}

private enum ToppingCameraPreviewFixtures {
    static let state = ToppingAddStore.State(
        entryPoint: .camera,
        cameraPhase: .running
    )

    @MainActor
    static var photoData: Data? {
        let renderer = ImageRenderer(
            content: CameraPreviewPlaceholder()
                .frame(width: 335, height: 596)
        )
        renderer.scale = 2
        return renderer.uiImage?.jpegData(compressionQuality: 0.9)
    }

    @MainActor
    static func cameraView(
        flashMode: ToppingAddStore.CameraFlashMode = .off,
        showsToast: Bool = false
    ) -> some View {
        ToppingCameraView(
            dateText: state.canvasDateText,
            weekdayText: state.canvasWeekdayText,
            flashMode: flashMode,
            isFlashControlEnabled: state.isFlashControlEnabled,
            isShutterEnabled: true,
            isSwitchingCamera: false,
            showsToast: showsToast,
            previewSource: nil,
            send: { _ in }
        )
    }
}

#Preview("C-101 · Camera") {
    ToppingCameraPreviewFixtures.cameraView()
}

#Preview("C-101 · Flash On") {
    ToppingCameraPreviewFixtures.cameraView(flashMode: .enabled)
}

#Preview("C-101 · Toast") {
    ToppingCameraPreviewFixtures.cameraView(showsToast: true)
}

#Preview("C-101 · Confirm") {
    ToppingCameraConfirmationView(
        photoData: ToppingCameraPreviewFixtures.photoData,
        onCloseTap: {},
        onRetakeTap: {},
        onNextTap: {}
    )
}

#Preview("C-101 · Permission Error") {
    ToppingErrorView(
        title: "카메라 권한이 없어요",
        message: "설정에서 카메라 권한을 허용해 주세요",
        actionTitle: "설정으로 이동",
        onActionTap: {},
        onCloseTap: {}
    )
}

#Preview("C-101 · Camera Unavailable") {
    ToppingErrorView(
        title: "카메라를 사용할 수 없어요",
        message: "잠시 후 다시 시도해 주세요",
        actionTitle: "다시 시도",
        onActionTap: {},
        onCloseTap: {}
    )
}
#endif
