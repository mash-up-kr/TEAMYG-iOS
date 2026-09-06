//
//  CameraCaptureContainer.swift
//  CanvasFeature
//
//  Created by 박서연 on 9/7/26.
//

import SwiftUI

/// C-101 카메라와 C-101-Confirm 을 겹쳐 두는 컨테이너.
///
/// 확인 화면은 실제 사진이 도착하기 전(프리즈 프레임 단계)에 먼저 뜬다. 이때 카메라 화면을 뷰 계층에서
/// 걷어내면 `CameraPreviewView` 의 `AVCaptureVideoPreviewLayer` 가 세션에서 빠지면서 진행 중인 촬영이
/// 중단된다 (`topping_ui.md` §3.2). 그래서 파괴하지 않고 감추기만 한다.
struct CameraCaptureContainer<Preview: View, Confirmation: View>: View {
    let isConfirming: Bool
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let confirmation: () -> Confirmation

    var body: some View {
        ZStack {
            preview()
                .opacity(isConfirming ? 0 : 1)
                .allowsHitTesting(!isConfirming)

            if isConfirming {
                confirmation()
            }
        }
    }
}
