//
//  ToppingAddFlowView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import SwiftUI
import UIComponent

struct ToppingAddFlowView: View {
    @State private var store: ToppingAddStore
    @Environment(\.scenePhase) private var scenePhase

    init(store: ToppingAddStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        Group {
            switch store.state.screen {
            case .camera:
                ToppingCameraView(
                    dateText: store.state.canvasDateText,
                    weekdayText: store.state.canvasWeekdayText,
                    flashMode: store.state.flashMode,
                    isFlashControlEnabled: store.state.isFlashControlEnabled,
                    isShutterEnabled: store.state.isShutterEnabled,
                    isSwitchingCamera: store.state.isSwitchingCamera,
                    showsToast: store.state.showsToast,
                    previewSource: store.previewSource,
                    send: { store.send($0) }
                )

            case .cameraConfirmation:
                ToppingCameraConfirmationView(
                    photoData: store.state.capturedPhotoData,
                    onRetakeTap: { store.send(.retakeTapped) },
                    onNextTap: { store.send(.photoConfirmed) }
                )

            case .cameraPermissionError:
                ToppingErrorView(
                    title: "카메라 권한이 없어요",
                    message: "설정에서 카메라 권한을 허용해 주세요",
                    actionTitle: "설정으로 이동",
                    onActionTap: { store.send(.settingsTapped) }
                )

            case .cameraUnavailable:
                ToppingErrorView(
                    title: "카메라를 사용할 수 없어요",
                    message: "잠시 후 다시 시도해 주세요",
                    actionTitle: "다시 시도",
                    onActionTap: { store.send(.cameraRetryTapped) }
                )

            case .analysisLoading:
                ToppingAnalysisLoadingView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            store.send(.screenAppeared)
        }
        .onDisappear {
            store.send(.screenDisappeared)
        }
        // `.inactive` 는 권한 다이얼로그·알림 배너·앱 스위처 등에서도 흔히 발생한다.
        // 여기서 세션을 끄면 껐다 켜기가 잦아져 최초 권한 요청 플로우가 끊기므로 `.background` 만 처리한다.
        // (백그라운드 진입 시엔 iOS 가 캡처 세션을 어차피 중단시킨다.)
        .onChange(of: scenePhase) { _, newScenePhase in
            switch newScenePhase {
            case .active:
                store.send(.sceneBecameActive)
            case .background:
                store.send(.sceneEnteredBackground)
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
