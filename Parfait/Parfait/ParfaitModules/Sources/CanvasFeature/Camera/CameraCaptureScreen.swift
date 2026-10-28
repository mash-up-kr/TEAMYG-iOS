//
//  CameraCaptureScreen.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/28/26.
//

import SwiftUI

/// 촬영 → 촬영 확인 화면. 토핑 추가와 배경 변경이 같이 쓴다 — 화면 전이는 각 Store 가 정한다.
struct CameraCaptureScreen: View {
    enum Action {
        case flashTapped
        case cameraPositionTapped
        case zoomChanged(CGFloat)
        case shutterTapped(ViewFinderRegion?)
        case retakeTapped
        case nextTapped
        case closeTapped
    }

    let isConfirming: Bool
    let dateText: String
    let weekdayText: String
    let cameraState: CameraFlowState
    let previewSource: any CameraPreviewSource
    let isNextEnabled: Bool
    var showsToast = false
    var onToastDismissed: () -> Void = {}
    let onAction: (Action) -> Void

    var body: some View {
        CameraCaptureContainer(isConfirming: isConfirming) {
            ToppingCameraView(
                dateText: dateText,
                weekdayText: weekdayText,
                flashMode: cameraState.flashMode,
                isFlashControlEnabled: cameraState.isFlashControlEnabled,
                isCameraReady: cameraState.isReady,
                showsToast: showsToast,
                previewSource: previewSource,
                onToastDismissed: onToastDismissed,
                onFlashTap: { onAction(.flashTapped) },
                onShutterTap: { onAction(.shutterTapped($0)) },
                onSwitchCameraTap: { onAction(.cameraPositionTapped) },
                zoomFactor: cameraState.zoomFactor,
                onZoomChange: { onAction(.zoomChanged($0)) },
                onCloseTap: { onAction(.closeTapped) }
            )
        } confirmation: {
            ToppingCameraConfirmationView(
                previewFrame: cameraState.previewFrame,
                photoData: cameraState.capturedPhotoData,
                viewFinderRegion: cameraState.capturedViewFinderRegion,
                isRetakeEnabled: cameraState.isRetakeEnabled,
                isNextEnabled: isNextEnabled,
                onRetakeTap: { onAction(.retakeTapped) },
                onNextTap: { onAction(.nextTapped) },
                onCloseTap: { onAction(.closeTapped) }
            )
        }
    }
}

extension CameraErrorScreen {
    static func permissionDenied(onCloseTap: @escaping () -> Void, onSettingsTap: @escaping () -> Void) -> Self {
        CameraErrorScreen(
            title: "카메라 권한이 없어요",
            message: "설정에서 카메라 권한을 허용해 주세요",
            buttonTitle: "설정으로 이동",
            onCloseTap: onCloseTap,
            action: onSettingsTap
        )
    }

    static func unavailable(onCloseTap: @escaping () -> Void, onRetryTap: @escaping () -> Void) -> Self {
        CameraErrorScreen(
            title: "카메라를 사용할 수 없어요",
            message: "잠시 후 다시 시도해 주세요",
            buttonTitle: "다시 시도",
            onCloseTap: onCloseTap,
            action: onRetryTap
        )
    }
}

extension View {
    /// 카메라 세션을 앱 활성·백그라운드 진입에 맞춰 켜고 끈다.
    ///
    /// `.inactive` 는 권한 다이얼로그·알림 배너·앱 스위처 등에서도 흔히 발생한다.
    /// 여기서 세션을 끄면 껐다 켜기가 잦아져 최초 권한 요청 플로우가 끊기므로 `.background` 만 처리한다.
    /// (백그라운드 진입 시엔 iOS 가 캡처 세션을 어차피 중단시킨다.)
    func onCameraScenePhaseChange(
        becameActive: @escaping () -> Void,
        enteredBackground: @escaping () -> Void
    ) -> some View {
        modifier(CameraScenePhaseModifier(becameActive: becameActive, enteredBackground: enteredBackground))
    }
}

private struct CameraScenePhaseModifier: ViewModifier {
    let becameActive: () -> Void
    let enteredBackground: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, newScenePhase in
            switch newScenePhase {
            case .active:
                becameActive()
            case .background:
                enteredBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
